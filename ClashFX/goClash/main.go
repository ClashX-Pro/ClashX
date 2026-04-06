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
	"net/netip"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	bbolt "github.com/metacubex/bbolt"
	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"github.com/oschwald/geoip2-golang"
	"github.com/phayes/freeport"
	"gopkg.in/yaml.v3"
)

var (
	secretOverride     string = ""
	enableIPV6         bool   = false
	tunEnabled         bool   = false
	tunRouteExcludeRaw string = ""
	tunMu              sync.Mutex
	savedUIPath        string
	callbacksPaused    int32 // atomic: 0=active, 1=paused
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

func mergeUniqueStrings(base []string, additions []string) []string {
	seen := make(map[string]struct{}, len(base)+len(additions))
	result := make([]string, 0, len(base)+len(additions))
	for _, item := range base {
		trimmed := strings.TrimSpace(item)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}
	for _, item := range additions {
		trimmed := strings.TrimSpace(item)
		if trimmed == "" {
			continue
		}
		if _, ok := seen[trimmed]; ok {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}
	return result
}

func parseEntryAsPrefix(s string) (netip.Prefix, bool) {
	if prefix, err := netip.ParsePrefix(s); err == nil {
		return prefix.Masked(), true
	}
	if ip, err := netip.ParseAddr(s); err == nil {
		bits := 32
		if ip.Is6() {
			bits = 128
		}
		return netip.PrefixFrom(ip, bits), true
	}
	return netip.Prefix{}, false
}

func splitTunRouteExcludeEntries(raw string) ([]netip.Prefix, []string, []string) {
	var prefixes []netip.Prefix
	var domains []string
	var invalid []string

	for _, item := range strings.Split(raw, ",") {
		entry := strings.TrimSpace(item)
		if entry == "" {
			continue
		}
		if prefix, ok := parseEntryAsPrefix(entry); ok {
			prefixes = append(prefixes, prefix)
			continue
		}
		if strings.Contains(entry, ".") || strings.HasPrefix(entry, "*.") || strings.HasPrefix(entry, "+.") {
			domains = append(domains, entry)
			continue
		}
		invalid = append(invalid, entry)
	}

	return prefixes, domains, invalid
}

func applyTunRouteExclusions(rawCfg *config.RawConfig) error {
	prefixes, domains, invalid := splitTunRouteExcludeEntries(tunRouteExcludeRaw)
	if len(invalid) > 0 {
		return fmt.Errorf("invalid TUN route exclude entries: %s", strings.Join(invalid, ", "))
	}
	if len(prefixes) > 0 {
		rawCfg.Tun.RouteExcludeAddress = mergeUniquePrefixes(rawCfg.Tun.RouteExcludeAddress, prefixes)
	}
	if len(domains) > 0 {
		rawCfg.DNS.FakeIPFilter = mergeUniqueStrings(rawCfg.DNS.FakeIPFilter, domains)
	}
	return nil
}

func mergeUniquePrefixes(base []netip.Prefix, additions []netip.Prefix) []netip.Prefix {
	seen := make(map[string]struct{}, len(base)+len(additions))
	result := make([]netip.Prefix, 0, len(base)+len(additions))
	for _, item := range base {
		key := item.Masked().String()
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, item.Masked())
	}
	for _, item := range additions {
		masked := item.Masked()
		key := masked.String()
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, masked)
	}
	return result
}

func mergeInterfaceSlice(base interface{}, additions []string) []interface{} {
	var existing []string
	switch value := base.(type) {
	case []interface{}:
		for _, item := range value {
			if str, ok := item.(string); ok {
				existing = append(existing, str)
			}
		}
	case []string:
		existing = append(existing, value...)
	}
	merged := mergeUniqueStrings(existing, additions)
	result := make([]interface{}, 0, len(merged))
	for _, item := range merged {
		result = append(result, item)
	}
	return result
}

func mergePrefixInterfaceSlice(base interface{}, additions []netip.Prefix) []interface{} {
	var existing []netip.Prefix
	switch value := base.(type) {
	case []interface{}:
		for _, item := range value {
			if str, ok := item.(string); ok {
				if prefix, ok := parseEntryAsPrefix(str); ok {
					existing = append(existing, prefix)
				}
			}
		}
	case []string:
		for _, item := range value {
			if prefix, ok := parseEntryAsPrefix(item); ok {
				existing = append(existing, prefix)
			}
		}
	case []netip.Prefix:
		existing = append(existing, value...)
	}
	merged := mergeUniquePrefixes(existing, additions)
	result := make([]interface{}, 0, len(merged))
	for _, item := range merged {
		result = append(result, item.String())
	}
	return result
}

//export initClashCore
func initClashCore() {
	// Reserve at least one CPU core for the UI thread to prevent Go goroutines
	// from saturating all cores during heavy operations (config switch, health checks)
	numCPU := runtime.NumCPU()
	if numCPU > 2 {
		runtime.GOMAXPROCS(numCPU - 1)
	}

	homeDir, _ := os.UserHomeDir()
	clashHome := filepath.Join(homeDir, ".config", "clashfx")
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
	rawCfg.ExternalUIURL = ""
	rawCfg.ExternalUIName = ""
	rawCfg.Profile.StoreSelected = true
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
		if err := applyTunRouteExclusions(rawCfg); err != nil {
			tunMu.Unlock()
			return nil, err
		}
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

	// Re-apply UI path after server recreation (ReCreateServer resets it)
	if savedUIPath != "" {
		route.SetUIPath(savedUIPath)
	}

	return cfg, nil
}

// applyTunConfig configures TUN and DNS settings on a RawConfig for Enhanced Mode.
// Must be called while tunMu is held.
func applyTunConfig(rawCfg *config.RawConfig) {
	rawCfg.Tun.Enable = true
	rawCfg.Tun.Stack = constant.TunMixed
	rawCfg.Tun.AutoRoute = true
	rawCfg.Tun.AutoDetectInterface = true
	rawCfg.Tun.StrictRoute = true
	rawCfg.Tun.DNSHijack = []string{"any:53", "tcp://any:53"}
	rawCfg.Tun.MTU = 9000

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
			if atomic.LoadInt32(&callbacksPaused) != 0 {
				continue
			}
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
			if atomic.LoadInt32(&callbacksPaused) != 0 {
				continue
			}
			buf.Reset()
			up, down := t.Now()
			C.sendTrafficToUI(C.longlong(up), C.longlong(down))
		}
	}()
}

//export clashPauseCallbacks
func clashPauseCallbacks() {
	atomic.StoreInt32(&callbacksPaused, 1)
}

//export clashResumeCallbacks
func clashResumeCallbacks() {
	atomic.StoreInt32(&callbacksPaused, 0)
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
	cfg.Controller.ExternalUI = ""
	cfg.Controller.ExternalUIURL = ""
	cfg.Controller.ExternalUIName = ""
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
	rawCfg.Profile.StoreSelected = false
	rawCfg.IPv6 = enableIPV6
	rawCfg.ExternalUI = ""
	rawCfg.ExternalUIURL = ""
	rawCfg.ExternalUIName = ""

	tunMu.Lock()
	if tunEnabled {
		applyTunConfig(rawCfg)
		if err := applyTunRouteExclusions(rawCfg); err != nil {
			tunMu.Unlock()
			return C.CString(err.Error())
		}
	} else {
		rawCfg.Tun.Enable = false
	}
	tunMu.Unlock()

	cfg, err := config.ParseRawConfig(rawCfg)
	if err != nil {
		return C.CString(err.Error())
	}

	executor.ApplyConfig(cfg, false)

	if enabled && !listener.GetTunConf().Enable {
		tunMu.Lock()
		tunEnabled = false
		tunMu.Unlock()
		return C.CString("TUN failed: operation not permitted (requires elevated privileges)")
	}

	return C.CString("success")
}

//export clashGetTunEnabled
func clashGetTunEnabled() bool {
	tunMu.Lock()
	defer tunMu.Unlock()
	return tunEnabled
}

//export clashSuspendCore
func clashSuspendCore() {
	// Close all proxy listeners to free ports for external mihomo_core
	listener.ReCreateHTTP(0, tunnel.Tunnel)
	listener.ReCreateSocks(0, tunnel.Tunnel)
	listener.ReCreateMixed(0, tunnel.Tunnel)
	listener.ReCreateRedir(0, tunnel.Tunnel)
	listener.ReCreateTProxy(0, tunnel.Tunnel)
	// Close the RESTful API server so external binary can use the same port
	route.ReCreateServer(&route.Config{})
	// Release cache.db file lock so external mihomo_core can open it
	cache := cachefile.Cache()
	if cache.DB != nil {
		cache.DB.Close()
	}
}

//export clashReopenCacheDB
func clashReopenCacheDB() {
	cache := cachefile.Cache()
	if cache.DB != nil {
		return
	}
	db, err := bbolt.Open(constant.Path.Cache(), 0o666, &bbolt.Options{Timeout: time.Second})
	if err == nil {
		cache.DB = db
	}
}

//export clashResumeCore
func clashResumeCore() *C.char {
	clashReopenCacheDB()

	cfg, err := parseDefaultConfigThenStart(false, false, enableIPV6, 0, "")
	if err != nil {
		return C.CString(err.Error())
	}
	_ = cfg
	return C.CString("success")
}

//export clashWriteEnhancedConfig
func clashWriteEnhancedConfig(configPath *C.char, outputPath *C.char, tunRouteExcludeList *C.char) *C.char {
	excludeRaw := C.GoString(tunRouteExcludeList)
	tunMu.Lock()
	tunRouteExcludeRaw = excludeRaw
	tunMu.Unlock()
	srcPath := C.GoString(configPath)
	if srcPath == "" {
		srcPath = constant.Path.Config()
	}
	buf, err := readConfig(srcPath)
	if err != nil {
		return C.CString("error:" + err.Error())
	}

	var rawMap map[string]interface{}
	if err := yaml.Unmarshal(buf, &rawMap); err != nil {
		return C.CString("error:" + err.Error())
	}

	rawMap["tun"] = map[string]interface{}{
		"enable":                true,
		"stack":                 "mixed",
		"auto-route":            true,
		"auto-detect-interface": true,
		"strict-route":          true,
		"dns-hijack":            []string{"any:53", "tcp://any:53"},
		"mtu":                   9000,
	}

	prefixes, domains, invalid := splitTunRouteExcludeEntries(excludeRaw)
	if len(invalid) > 0 {
		return C.CString("error:invalid TUN route exclude entries: " + strings.Join(invalid, ", "))
	}

	dns, _ := rawMap["dns"].(map[string]interface{})
	if dns == nil {
		dns = map[string]interface{}{}
	}
	dns["enable"] = true
	if len(domains) > 0 {
		dns["fake-ip-filter"] = mergeInterfaceSlice(dns["fake-ip-filter"], domains)
	}
	if mode, _ := dns["enhanced-mode"].(string); mode == "" || mode == "normal" {
		dns["enhanced-mode"] = "fake-ip"
	}
	if fir, _ := dns["fake-ip-range"].(string); fir == "" {
		dns["fake-ip-range"] = "198.18.0.1/16"
	}
	if dns["nameserver"] == nil {
		dns["nameserver"] = []string{"https://doh.pub/dns-query", "tls://223.5.5.5:853"}
	}
	if dns["default-nameserver"] == nil {
		dns["default-nameserver"] = []string{"114.114.114.114", "223.5.5.5", "8.8.8.8"}
	}
	// Use a free port for DNS listen to avoid conflict with in-process clash core
	if dnsPort, err := freeport.GetFreePort(); err == nil {
		dns["listen"] = "127.0.0.1:" + strconv.Itoa(dnsPort)
	} else {
		dns["listen"] = "127.0.0.1:11053"
	}
	rawMap["dns"] = dns
	if len(prefixes) > 0 {
		tunMap, _ := rawMap["tun"].(map[string]interface{})
		tunMap["route-exclude-address"] = mergePrefixInterfaceSlice(tunMap["route-exclude-address"], prefixes)
		rawMap["tun"] = tunMap
	}

	if port, err := freeport.GetFreePort(); err == nil {
		rawMap["external-controller"] = "127.0.0.1:" + strconv.Itoa(port)
	} else {
		rawMap["external-controller"] = "127.0.0.1:19090"
	}
	ec := rawMap["external-controller"].(string)

	if secretOverride != "" {
		rawMap["secret"] = secretOverride
	}
	rawMap["ipv6"] = enableIPV6
	if savedUIPath != "" {
		rawMap["external-ui"] = savedUIPath
	}

	profile, _ := rawMap["profile"].(map[string]interface{})
	if profile == nil {
		profile = map[string]interface{}{}
	}
	profile["store-selected"] = true
	rawMap["profile"] = profile

	mixedPort, _ := rawMap["mixed-port"].(int)
	httpPort, _ := rawMap["port"].(int)
	socksPort, _ := rawMap["socks-port"].(int)
	if mixedPort == 0 && httpPort == 0 && socksPort == 0 {
		rawMap["mixed-port"] = 7890
	}

	data, err := yaml.Marshal(rawMap)
	if err != nil {
		return C.CString("error:" + err.Error())
	}

	path := C.GoString(outputPath)
	if err := os.WriteFile(path, data, 0644); err != nil {
		return C.CString("error:" + err.Error())
	}

	secret, _ := rawMap["secret"].(string)
	portInfo := map[string]string{
		"externalController": ec,
		"secret":             secret,
	}
	jsonString, err := json.Marshal(portInfo)
	if err != nil {
		return C.CString("error:" + err.Error())
	}
	return C.CString(string(jsonString))
}

func main() {
}
