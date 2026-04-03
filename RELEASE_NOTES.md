## ClashFX 1.0.4

### Bug Fixes

- **Fix proxy groups not showing all proxies** — Proxies using newer protocols (Hysteria, Hysteria2, TUIC, SSH, Anytls) were silently dropped due to unknown type decoding failure. Now all proxy types display correctly (#6)

### Improvements

- **Sparkle auto-update** — Replace manual browser-based updates with Sparkle native auto-update. Check for Updates now downloads, installs, and relaunches automatically
- **Fix CI code signing** — Release builds are now properly ad-hoc signed, enabling Sparkle signature validation

---

### 修复

- **修复代理组不显示全部节点** — 使用新协议（Hysteria、Hysteria2、TUIC、SSH、Anytls）的节点因类型解码失败被静默跳过，现在所有代理类型都能正常显示 (#6)

### 改进

- **Sparkle 自动更新** — 用 Sparkle 原生自动更新替代手动打开浏览器下载。检查更新现在可以自动下载、安装并重启
- **修复 CI 代码签名** — Release 构建现在使用正确的 ad-hoc 签名，确保 Sparkle 签名校验通过
