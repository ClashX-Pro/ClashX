<h1 align="center">
  <img src="./clashx.png" alt="Clash" width="200">
  <br>
  ClashX
  <br>
</h1>

<div align="center">

[English](README.md) | [简体中文](README_zh-CN.md)

</div>

## Maintenance status

**ClashX is no longer maintained. Please migrate to [ClashFX](https://clashfx.com/).**

This repository keeps the existing ClashX source code, releases and historical discussions available for reference. There are no plans for further ClashX feature development, compatibility updates or routine bug fixes. Existing issues and pull requests are not automatically closed or transferred by this notice.

- [ClashFX website](https://clashfx.com/)
- [Download ClashFX](https://clashfx.com/en/download/)
- [Migrate from ClashX: backup, import, verification and rollback](https://clashfx.com/en/guides/migrate-from-clashx/)
- [ClashFX repository and feedback](https://github.com/Clash-FX/ClashFX)

Check ClashFX's system requirements before migrating. Back up your configuration and do not run both clients against the system proxy or TUN at the same time. Migration is not a guarantee that a reported ClashX issue is fixed in ClashFX.

ClashFX's current core features are free to use. ClashFX Pro is in preparation and is not available to purchase. The historical product named ClashX Pro is separate from both standard ClashX and the planned ClashFX Pro.

## Legacy downloads and documentation

- [Retained ClashX 1.140.0 release](https://github.com/ClashX-Pro/ClashX/releases/tag/1.140.0)
- [All historical ClashX releases](https://github.com/ClashX-Pro/ClashX/releases)
- [ClashX website and retained downloads](https://clashx.tech/)
- [Configuration tutorials](https://clashx.tech/tutorial)
- [Existing issues](https://github.com/ClashX-Pro/ClashX/issues)

ClashX is a proxy client and does not provide proxy servers or subscriptions. Contact your provider about server availability or renewals.

## Project background

This project is based on code originally created by [yichengchen](https://github.com/yichengchen), obtained from [bannedbook/ClashX](https://github.com/bannedbook/ClashX), with subsequent macOS compatibility changes. The original git history was lost when the `.git` directory was accidentally deleted while recreating the project.

The [1.140.0 source tag](https://github.com/ClashX-Pro/ClashX/blob/1.140.0/ClashX/goClash/go.mod) already depends on mihomo v1.19.24. Core capabilities do not mean every feature is exposed by this legacy client's interface. This repository is standard ClashX, not the historical ClashX Pro application.

## Retained features


- HTTP/HTTPS and SOCKS protocol support
- Surge-like configuration
- GeoIP rule support
- Support for Vmess/Shadowsocks/Socks5/Trojan protocols
- Netfilter TCP redirect support
- macOS 10.14+ compatibility
- Historical macOS compatibility fixes; newer system releases are no longer tested or maintained

## 📥 Installation

Historical ClashX installers remain available on the [Releases](https://github.com/ClashX-Pro/ClashX/releases) page.

For a maintained client, see [ClashFX](https://clashfx.com/) and its [migration guide](https://clashfx.com/en/guides/migrate-from-clashx/). Check compatibility before installing.

## Legacy build instructions

These instructions are retained for reference and are not maintained against newer Xcode or macOS releases.

### Prerequisites

- macOS 10.14 or later
- Xcode 15.0+
- Python 3
- Golang 1.21+

### Build Steps

1. **Install Golang**
   ```bash
   brew install golang
   # or download from https://golang.org
   ```

2. **Install dependencies**
   ```bash
   bash install_dependency.sh
   ```

3. **Open and build**
   ```bash
   open ClashX.xcworkspace
   # Build in Xcode (Cmd+R)
   ```

## ⚙️ Configuration

### Default Paths

The default configuration directory is `$HOME/.config/clash`

The default configuration file name is `config.yaml`. You can use custom config names and switch between them in the `Config` menu.

For more details, check out [SS-Rule-Snippet for Clash](https://github.com/Hackl0us/SS-Rule-Snippet/blob/master/LAZY_RULES/clash.yaml).

## 🔧 Advanced Configuration

### Change Proxy Port

Go to Menu Bar → Config → More Settings and modify the corresponding port numbers.

### Customize Status Menu Icon

Place your icon file at `~/.config/clash/menuImage.png`, then restart ClashX.

### Change Default System Ignore List

Navigate to Menu → Config → Settings → Bypass proxy settings for these Hosts & Domains.

### URL Schemes

- **Import remote config:**
  ```
  clash://install-config?url=http%3A%2F%2Fexample.com&name=example
  ```

- **Reload current config:**
  ```
  clash://update-config
  ```

### Get Process Name

Add the following to your config file and set proxy mode to rule. View logs via the Help menu:

```yaml
script:
  code: |
    def main(ctx, metadata):
      # Log ProcessName
      ctx.log('Process Name: ' + ctx.resolve_process_name(metadata))
      return 'DIRECT'
```

### Disable Notifications

1. Go to System Settings and disable ClashX notification permissions
2. Enable "Reduce Notifications" in Menu Bar → Config → More Settings

**Note:** Not recommended as you may miss important error notifications.

### Global Shortcuts

- Customize shortcuts in Menu Bar → Config → More Settings (requires v1.116.1+)
- Or use AppleScript - see [Shortcuts Guide](Shortcuts.md)

## ❓ FAQ

**Q: How to get shell commands with external IP?**
A: Click the ClashX menu icon and press `Option-Command-C`

## 🤝 Contributing

ClashX is no longer maintained, and new feature work should be proposed in [ClashFX](https://github.com/Clash-FX/ClashFX/issues). Historical reports and contributions remain available for reference; review, fixes and new ClashX releases are not promised.

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Based on the original ClashX project.
