<h1 align="center">
  ClashFX
  <br>
</h1>

<h4 align="center">A rule-based macOS proxy client with Enhanced Mode (TUN) — powered by mihomo core.</h4>

<div align="center">

[English](README.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [日本語](README_ja.md) | [Русский](README_ru.md)

</div>

---

## ✨ Features

- **Enhanced Mode (TUN)** — Global traffic capture via TUN device, one-click setup
- HTTP/HTTPS and SOCKS protocol support
- Rule-based routing (Domain, IP-CIDR, GeoIP, Process)
- Support for VMess/VLESS/Trojan/Shadowsocks/Hysteria2 protocols
- DNS security with Fake-IP mode
- gVisor userspace network stack
- Apple Silicon native support
- macOS 10.14+ compatibility (including macOS 15 Sequoia)

## 📥 Installation

Download from the [Releases](https://github.com/Clash-FX/ClashFX/releases) page.

## 🔨 Build from Source

### Prerequisites

- macOS 10.14 or later
- Xcode 15.0+
- Python 3
- Golang 1.21+

### Build Steps

1. **Install Golang**
   ```bash
   brew install golang
   ```

2. **Install dependencies**
   ```bash
   bash install_dependency.sh
   ```

3. **Open and build**
   ```bash
   open ClashFX.xcworkspace
   # Build in Xcode (Cmd+R)
   ```

## ⚙️ Configuration

### Default Paths

The default configuration directory is `$HOME/.config/clash`

The default configuration file name is `config.yaml`. You can use custom config names and switch between them in the `Config` menu.

### Enhanced Mode

ClashFX's core feature — TUN-based global proxy that captures all TCP/UDP traffic from every application, not just browsers.

**How to enable:**
1. Menu Bar → Enhanced Mode → Enable
2. Grant administrator privileges on first use
3. All traffic is now routed through ClashFX

### URL Schemes

- **Import remote config:**
  ```
  clashfx://install-config?url=http%3A%2F%2Fexample.com&name=example
  clash://install-config?url=http%3A%2F%2Fexample.com&name=example
  ```

- **Reload current config:**
  ```
  clash://update-config
  ```

## 📄 License

[AGPL-3.0](LICENSE)

## 🙏 Acknowledgments

- [mihomo](https://github.com/MetaCubeX/mihomo) — Core proxy engine
- [ClashX](https://github.com/bannedbook/ClashX) — Original macOS client
- [Yacd-meta](https://github.com/MetaCubeX/Yacd-meta) — Dashboard UI
