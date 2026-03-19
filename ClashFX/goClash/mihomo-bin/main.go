package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/log"
)

func main() {
	configFile := flag.String("f", "", "config file path")
	homeDir := flag.String("d", "", "config home directory")
	flag.Parse()

	if *homeDir != "" {
		constant.SetHomeDir(*homeDir)
	}

	if *configFile != "" {
		if !filepath.IsAbs(*configFile) {
			currentDir, _ := os.Getwd()
			*configFile = filepath.Join(currentDir, *configFile)
		}
		constant.SetConfig(*configFile)
	} else {
		configPath := filepath.Join(constant.Path.HomeDir(), constant.Path.Config())
		constant.SetConfig(configPath)
	}

	fmt.Printf("mihomo-bin euid=%d uid=%d pid=%d\n", os.Geteuid(), os.Getuid(), os.Getpid())

	if err := hub.Parse(nil); err != nil {
		log.Fatalln("Parse config error: %s", err.Error())
	}

	fmt.Printf("mihomo-bin started, config: %s\n", constant.Path.Config())

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
}
