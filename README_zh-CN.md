<h1 align="center">
  ClashFX
  <br>
</h1>

<h4 align="center">带增强模式 (TUN) 的 macOS 规则代理客户端 — 基于 mihomo 内核</h4>

<div align="center">

[English](README.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [日本語](README_ja.md) | [Русский](README_ru.md)

</div>

---

## ✨ 功能特性

- **增强模式 (TUN)** — 通过 TUN 虚拟网卡全局流量捕获，一键开启
- 支持 HTTP/HTTPS 和 SOCKS 协议
- 规则路由（域名、IP-CIDR、GeoIP、进程匹配）
- 支持 VMess/VLESS/Trojan/Shadowsocks/Hysteria2 协议
- DNS 安全（Fake-IP 模式）
- gVisor 用户态网络栈
- Apple Silicon 原生支持
- 支持 macOS 10.14+（包括 macOS 15 Sequoia）

## 📥 安装

从 [Releases](https://github.com/Clash-FX/ClashFX/releases) 页面下载。

## 🔨 从源码构建

### 环境要求

- macOS 10.14 或更高版本
- Xcode 15.0+
- Python 3
- Golang 1.21+

### 构建步骤

1. **安装 Golang**
   ```bash
   brew install golang
   ```

2. **安装依赖**
   ```bash
   bash install_dependency.sh
   ```

3. **打开并构建**
   ```bash
   open ClashFX.xcworkspace
   # 在 Xcode 中构建 (Cmd+R)
   ```

## ⚙️ 配置

### 默认路径

默认配置目录为 `$HOME/.config/clash`

默认配置文件名为 `config.yaml`。你可以使用自定义配置名称，并在 `配置` 菜单中切换。

### 增强模式

ClashFX 的核心功能 — 基于 TUN 的全局代理，捕获所有应用的 TCP/UDP 流量，不仅限于浏览器。

**开启方法：**
1. 菜单栏 → 增强模式 → 开启
2. 首次使用需要授予管理员权限
3. 所有流量现在都通过 ClashFX 路由

### URL Schemes

- **导入远程配置：**
  ```
  clashfx://install-config?url=http%3A%2F%2Fexample.com&name=example
  clash://install-config?url=http%3A%2F%2Fexample.com&name=example
  ```

- **重新加载当前配置：**
  ```
  clash://update-config
  ```

## 📄 许可证

[AGPL-3.0](LICENSE)

## 🙏 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) — 代理引擎内核
- [ClashX](https://github.com/bannedbook/ClashX) — 原始 macOS 客户端
- [Yacd-meta](https://github.com/MetaCubeX/Yacd-meta) — Dashboard 面板
