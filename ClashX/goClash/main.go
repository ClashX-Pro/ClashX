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
	"time"
	"unsafe"

	"github.com/metacubex/mihomo/common/convert"
	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"github.com/phayes/freeport"
	"gopkg.in/yaml.v3"
)

var secretOverride string = ""
var enableIPV6 bool = false
var savedUIPath string

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
	// Keep config directory at ~/.config/clash/ for backward compatibility.
	// mihomo defaults to ~/.config/mihomo/ which would break existing user configs.
	homeDir, _ := os.UserHomeDir()
	constant.SetHomeDir(filepath.Join(homeDir, ".config", "clash"))
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

	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return nil, err
	}
	go route.ReCreateServer(&route.Config{
		Addr:   cfg.Controller.ExternalController,
		Secret: cfg.Controller.Secret,
	})
	executor.ApplyConfig(cfg, true)
	return cfg, nil
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

//export clashConvertShareLinks
func clashConvertShareLinks(content *C.char) *C.char {
	proxies, err := convert.ConvertsV2Ray([]byte(C.GoString(content)))
	if err != nil {
		return C.CString("error:" + err.Error())
	}

	names := make([]string, 0, len(proxies))
	for _, proxy := range proxies {
		if name, ok := proxy["name"].(string); ok && name != "" {
			names = append(names, name)
		}
	}
	if len(names) == 0 {
		return C.CString("error:converted subscription did not contain proxy names")
	}

	rawMap := map[string]interface{}{
		"mode":         "rule",
		"log-level":    "info",
		"geodata-mode": true,
		"mixed-port":   7890,
		"allow-lan":    false,
		"geox-url": map[string]interface{}{
			"geoip":   "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat",
			"geosite": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat",
			"mmdb":    "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb",
		},
		"dns": map[string]interface{}{
			"enable":        true,
			"ipv6":          false,
			"enhanced-mode": "redir-host",
			"nameserver": []string{
				"223.5.5.5",
				"119.29.29.29",
			},
			"fallback": []string{
				"1.1.1.1",
				"8.8.8.8",
			},
			"fallback-filter": map[string]interface{}{
				"geoip":      true,
				"geoip-code": "CN",
			},
		},
		"proxies": proxies,
		"proxy-groups": []map[string]interface{}{
			{
				"name":     "Auto",
				"type":     "url-test",
				"proxies":  names,
				"url":      "http://cp.cloudflare.com/generate_204",
				"interval": 300,
			},
			{
				"name":    "Proxy",
				"type":    "select",
				"proxies": append([]string{"Auto", "DIRECT"}, names...),
			},
		},
		"rules": []string{
			"DOMAIN,localhost,DIRECT",
			"DOMAIN-SUFFIX,local,DIRECT",
			"DOMAIN-SUFFIX,cn,DIRECT",
			"GEOSITE,private,DIRECT",
			"GEOSITE,cn,DIRECT",
			"DOMAIN,www.baidu.com,DIRECT",
			"DOMAIN,baidu.com,DIRECT",
			"DOMAIN-KEYWORD,baidu,DIRECT",
			"DOMAIN-SUFFIX,baidu.com,DIRECT",
			"DOMAIN-SUFFIX,bdimg.com,DIRECT",
			"DOMAIN-SUFFIX,bdstatic.com,DIRECT",
			"IP-CIDR,127.0.0.0/8,DIRECT,no-resolve",
			"IP-CIDR,10.0.0.0/8,DIRECT,no-resolve",
			"IP-CIDR,172.16.0.0/12,DIRECT,no-resolve",
			"IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
			"IP-CIDR,100.64.0.0/10,DIRECT,no-resolve",
			"IP-CIDR,169.254.0.0/16,DIRECT,no-resolve",
			"IP-CIDR,224.0.0.0/4,DIRECT,no-resolve",
			"IP-CIDR6,::1/128,DIRECT,no-resolve",
			"IP-CIDR6,fc00::/7,DIRECT,no-resolve",
			"IP-CIDR6,fe80::/10,DIRECT,no-resolve",
			"GEOIP,private,DIRECT",
			"GEOIP,CN,DIRECT",
			"MATCH,Proxy",
		},
	}

	data, err := yaml.Marshal(rawMap)
	if err != nil {
		return C.CString("error:" + err.Error())
	}

	header := "# clashx-generated: share-links\n" +
		"# clashx-template-version: 5\n" +
		"# This file was auto-generated by ClashX from share-link subscriptions.\n" +
		"# It is a compatibility config, not a user-authored rule file.\n" +
		"# ClashX may safely auto-upgrade this generated template.\n" +
		"# Current template: mihomo share-link converter + geosite/geoip CN direct routing.\n"
	return C.CString(header + string(data))
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
	savedUIPath = C.GoString(path)
	route.SetUIPath(savedUIPath)
}

//export clashUpdateConfig
func clashUpdateConfig(path *C.char) *C.char {
	cfg, err := executor.ParseWithPath(C.GoString(path))
	if err != nil {
		return C.CString(err.Error())
	}
	cfg.General.IPv6 = enableIPV6

	currentGeneral := executor.GetGeneral()

	if cfg.General.MixedPort > 0 && cfg.General.MixedPort != currentGeneral.MixedPort && !checkPortAvailable(cfg.General.MixedPort) {
		if port, err := freeport.GetFreePort(); err == nil {
			cfg.General.MixedPort = port
		}
	}
	if cfg.General.Port > 0 && cfg.General.Port != currentGeneral.Port && !checkPortAvailable(cfg.General.Port) {
		cfg.General.Port = 0
	}
	if cfg.General.SocksPort > 0 && cfg.General.SocksPort != currentGeneral.SocksPort && !checkPortAvailable(cfg.General.SocksPort) {
		cfg.General.SocksPort = 0
	}

	executor.ApplyConfig(cfg, false)
	if savedUIPath != "" {
		route.SetUIPath(savedUIPath)
	}
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
	return mmdb.Verify(constant.Path.MMDB())
}

//export clash_getCountryForIp
func clash_getCountryForIp(ip *C.char) *C.char {
	codes := mmdb.IPInstance().LookupCode(net.ParseIP(C.GoString(ip)))
	if len(codes) > 0 {
		return C.CString(codes[0])
	}
	return C.CString("")
}

//export clash_closeAllConnections
func clash_closeAllConnections() {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		c.Close()
		return true
	})
}

//export clash_getProggressInfo
func clash_getProggressInfo() *C.char {
	return C.CString(GetTcpNetList() + GetUDpList())
}

func main() {
}
