package main

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation
#import <Foundation/Foundation.h>
#import "UIHelper.h"
*/
import "C"

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"github.com/oschwald/geoip2-golang"
	"github.com/phayes/freeport"
)

var (
	secretOverride string = ""
	enableIPV6     bool   = false
	tunEnabled     bool   = false
	tunMu          sync.Mutex
)

func isAddrValid(addr string) bool {
	if addr != "" {
		comps := strings.Split(addr, ":")
		v := comps[len(comps)-1]
		if port, err := strconv.Atoi(v); err == nil {
			if port > 0 && port < 65535 {
				return checkPortAvailable(port)
			}
		}
	}
	return false
}

func checkPortAvailable(port int) bool {
	if port < 1 || port > 65534 {
		return false
	}
	addr := ":"
	l, err := net.Listen("tcp", addr+strconv.Itoa(port))
	if err != nil {
		log.Warnln("check port fail 0.0.0.0:%d", port)
		return false
	}
	_ = l.Close()

	addr = "127.0.0.1:"
	l, err = net.Listen("tcp", addr+strconv.Itoa(port))
	if err != nil {
		log.Warnln("check port fail 127.0.0.1:%d", port)
		return false
	}
	_ = l.Close()
	log.Infoln("check port %d success", port)
	return true
}

//export initClashCore
func initClashCore() {
	homeDir, _ := os.UserHomeDir()
	clashHome := filepath.Join(homeDir, ".config", "clash")
	constant.SetHomeDir(clashHome)
	configFile := filepath.Join(constant.Path.HomeDir(), constant.Path.Config())
	constant.SetConfig(configFile)
}

func readConfig(path string) ([]byte, error) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, fmt.Errorf("Configuration file %s is empty", path)
	}
	return data, err
}

func getRawCfg() (*config.RawConfig, error) {
	buf, err := readConfig(constant.Path.Config())
	if err != nil {
		return nil, err
	}

	return config.UnmarshalRawConfig(buf)
}

func parseDefaultConfigThenStart(checkPort, allowLan, ipv6 bool, proxyPort uint32, externalController string) (*config.Config, error) {
	rawCfg, err := getRawCfg()
	if err != nil {
		return nil, err
	}

	if proxyPort > 0 {
		rawCfg.MixedPort = int(proxyPort)
		if rawCfg.Port == rawCfg.MixedPort {
			rawCfg.Port = 0
		}
		if rawCfg.SocksPort == rawCfg.MixedPort {
			rawCfg.SocksPort = 0
		}
	} else {
		if rawCfg.MixedPort == 0 {
			if rawCfg.Port > 0 {
				rawCfg.MixedPort = rawCfg.Port
				rawCfg.Port = 0
			} else if rawCfg.SocksPort > 0 {
				rawCfg.MixedPort = rawCfg.SocksPort
				rawCfg.SocksPort = 0
			} else {
				rawCfg.MixedPort = 7890
			}

			if rawCfg.SocksPort == rawCfg.MixedPort {
				rawCfg.SocksPort = 0
			}

			if rawCfg.Port == rawCfg.MixedPort {
				rawCfg.Port = 0
			}
		}
	}
	if secretOverride != "" {
		rawCfg.Secret = secretOverride
	}
	rawCfg.ExternalUI = ""
	rawCfg.Profile.StoreSelected = false
	enableIPV6 = ipv6
	rawCfg.IPv6 = ipv6
	if len(externalController) > 0 {
		rawCfg.ExternalController = externalController
	}
	if checkPort {
		if !isAddrValid(rawCfg.ExternalController) {
			port, err := freeport.GetFreePort()
			if err != nil {
				return nil, err
			}
			rawCfg.ExternalController = "127.0.0.1:" + strconv.Itoa(port)
			rawCfg.Secret = ""
		}
		rawCfg.AllowLan = allowLan

		if !checkPortAvailable(rawCfg.MixedPort) {
			if port, err := freeport.GetFreePort(); err == nil {
				rawCfg.MixedPort = port
			}
		}
	}

	// Apply TUN configuration if enhanced mode is enabled
	tunMu.Lock()
	if tunEnabled {
		applyTunConfig(rawCfg)
	}
	tunMu.Unlock()

	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return nil, err
	}

	// Start the RESTful API server
	route.ReCreateServer(&route.Config{
		Addr:   cfg.Controller.ExternalController,
		Secret: cfg.Controller.Secret,
	})

	executor.ApplyConfig(cfg, true)
	return cfg, nil
}

// applyTunConfig configures TUN and DNS settings on a RawConfig for Enhanced Mode.
// Must be called while tunMu is held.
func applyTunConfig(rawCfg *config.RawConfig) {
	rawCfg.Tun.Enable = true
	rawCfg.Tun.Stack = constant.TunGvisor
	rawCfg.Tun.AutoRoute = true
	rawCfg.Tun.AutoDetectInterface = true
	rawCfg.Tun.DNSHijack = []string{"0.0.0.0:53"}

	// TUN mode requires DNS with fake-ip or redir-host
	if !rawCfg.DNS.Enable {
		rawCfg.DNS.Enable = true
	}
	if rawCfg.DNS.EnhancedMode == constant.DNSNormal {
		rawCfg.DNS.EnhancedMode = constant.DNSFakeIP
	}
	if rawCfg.DNS.FakeIPRange == "" {
		rawCfg.DNS.FakeIPRange = "198.18.0.1/16"
	}
	if len(rawCfg.DNS.NameServer) == 0 {
		rawCfg.DNS.NameServer = []string{
			"https://doh.pub/dns-query",
			"tls://223.5.5.5:853",
		}
	}
	if len(rawCfg.DNS.DefaultNameserver) == 0 {
		rawCfg.DNS.DefaultNameserver = []string{
			"114.114.114.114",
			"223.5.5.5",
			"8.8.8.8",
		}
	}
}

//export verifyClashConfig
func verifyClashConfig(content *C.char) *C.char {

	b := []byte(C.GoString(content))
	cfg, err := executor.ParseWithBytes(b)
	if err != nil {
		return C.CString(err.Error())
	}

	if len(cfg.Proxies) < 1 {
		return C.CString("No proxy found in config")
	}
	return C.CString("success")
}

//export clashSetupLogger
func clashSetupLogger() {
	sub := log.Subscribe()
	go func() {
		for elm := range sub {
			cs := C.CString(elm.Payload)
			cl := C.CString(elm.Type())
			C.sendLogToUI(cs, cl)
			C.free(unsafe.Pointer(cs))
			C.free(unsafe.Pointer(cl))
		}
	}()
}

//export clashSetupTraffic
func clashSetupTraffic() {
	go func() {
		tick := time.NewTicker(time.Second)
		defer tick.Stop()
		t := statistic.DefaultManager
		buf := &bytes.Buffer{}
		for range tick.C {
			buf.Reset()
			up, down := t.Now()
			C.sendTrafficToUI(C.longlong(up), C.longlong(down))
		}
	}()
}

//export clash_checkSecret
func clash_checkSecret() *C.char {
	cfg, err := getRawCfg()
	if err != nil {
		return C.CString("")
	}
	if cfg.Secret != "" {
		return C.CString(cfg.Secret)
	}
	return C.CString("")
}

//export clash_setSecret
func clash_setSecret(secret *C.char) {
	secretOverride = C.GoString(secret)
}

//export run
func run(checkConfig, allowLan, ipv6 bool, portOverride uint32, externalController *C.char) *C.char {
	cfg, err := parseDefaultConfigThenStart(checkConfig, allowLan, ipv6, portOverride, C.GoString(externalController))
	if err != nil {
		return C.CString(err.Error())
	}

	portInfo := map[string]string{
		"externalController": cfg.Controller.ExternalController,
		"secret":             cfg.Controller.Secret,
	}

	jsonString, err := json.Marshal(portInfo)
	if err != nil {
		return C.CString(err.Error())
	}

	return C.CString(string(jsonString))
}

//export setUIPath
func setUIPath(path *C.char) {
	route.SetUIPath(C.GoString(path))
}

//export clashUpdateConfig
func clashUpdateConfig(path *C.char) *C.char {
	cfg, err := executor.ParseWithPath(C.GoString(path))
	if err != nil {
		return C.CString(err.Error())
	}
	cfg.General.IPv6 = enableIPV6
	executor.ApplyConfig(cfg, false)
	return C.CString("success")
}

//export clashGetConfigs
func clashGetConfigs() *C.char {
	general := executor.GetGeneral()
	jsonString, err := json.Marshal(general)
	if err != nil {
		return C.CString(err.Error())
	}
	return C.CString(string(jsonString))
}

//export verifyGEOIPDataBase
func verifyGEOIPDataBase() bool {
	mmdb, err := geoip2.Open(constant.Path.MMDB())
	if err != nil {
		log.Warnln("mmdb fail:%s", err.Error())
		return false
	}

	_, err = mmdb.Country(net.ParseIP("114.114.114.114"))
	if err != nil {
		log.Warnln("mmdb lookup fail:%s", err.Error())
		return false
	}
	return true
}

//export clash_getCountryForIp
func clash_getCountryForIp(ip *C.char) *C.char {
	codes := mmdb.IPInstance().LookupCode(net.ParseIP(C.GoString(ip)))
	if len(codes) > 0 {
		return C.CString(strings.ToUpper(codes[0]))
	}
	return C.CString("")
}

//export clash_closeAllConnections
func clash_closeAllConnections() {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		return true
	})
}

//export clash_getProggressInfo
func clash_getProggressInfo() *C.char {
	return C.CString(GetTcpNetList() + GetUDpList())
}

// --- Enhanced Mode (TUN) Control Functions ---

//export clashPresetTunEnabled
func clashPresetTunEnabled(enabled bool) {
	tunMu.Lock()
	tunEnabled = enabled
	tunMu.Unlock()
}

//export clashSetTunEnabled
func clashSetTunEnabled(enabled bool) *C.char {
	tunMu.Lock()
	tunEnabled = enabled
	tunMu.Unlock()

	// Re-parse and apply the config with TUN settings
	rawCfg, err := getRawCfg()
	if err != nil {
		return C.CString(err.Error())
	}

	// Apply port/secret overrides from the currently running config
	if secretOverride != "" {
		rawCfg.Secret = secretOverride
	}
	rawCfg.ExternalUI = ""
	rawCfg.Profile.StoreSelected = false
	rawCfg.IPv6 = enableIPV6

	tunMu.Lock()
	if tunEnabled {
		applyTunConfig(rawCfg)
	} else {
		rawCfg.Tun.Enable = false
	}
	tunMu.Unlock()

	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return C.CString(err.Error())
	}

	executor.ApplyConfig(cfg, false)
	return C.CString("success")
}

//export clashGetTunEnabled
func clashGetTunEnabled() bool {
	tunMu.Lock()
	defer tunMu.Unlock()
	return tunEnabled
}

func main() {
}
