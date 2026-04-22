## ClashFX 1.0.14

### Bug Fixes / 问题修复

- **Fixed menu bar icon shrinking when realtime speed is disabled** — ClashFX had already fixed this once, but a later XIB layout change reintroduced a permanent leading constraint between the icon and hidden speed container. The status item now follows the original ClashFX fix again, so disabling realtime speed no longer compresses the tray icon.

- **Fixed Config Editor appearance in dark and light mode** — The raw editor, line number ruler, and visual editor sidebar previously used hard-coded dark colors. ClashFX now uses semantic system colors so the Config Editor follows the current macOS appearance correctly in both light and dark mode.

- **Improved share-link generated configs for domestic sites** — When ClashFX builds a minimal Clash config from `ss://` share-link subscriptions, it now enables `dns:` and adds direct rules for `baidu.com`, `bdimg.com`, and `bdstatic.com`, reducing cases where domestic domains fall through to `MATCH,Proxy`.

- **Improved Settings tab icon compatibility on older macOS** — The Settings window now falls back to generated icons on systems that do not support SF Symbols, instead of leaving missing tab icons.

- **Improved menu bar speed text compatibility on older macOS** — The status bar speed view now uses a legacy text-label fallback on older systems while keeping the custom draw path for newer macOS versions.

---

### 改进

- **修复关闭实时速率后菜单栏图标变小** — 这个问题在 ClashFX 里以前其实修过一次，但后续 XIB 布局调整又重新引入了一条固定间距约束，导致隐藏速度区域时图标被挤压。现在已恢复为 ClashFX 原先正确的约束切换逻辑，关闭实时速率后图标不再变小。

- **修复 Config Editor 在深色 / 浅色模式下显示异常** — 原始编辑器、行号区域和可视化编辑器侧边栏之前写死了深色配色。现在已改为使用系统语义色，能够跟随 macOS 当前外观正确切换。

- **改进分享链接生成配置对国内站点的处理** — 当 ClashFX 从 `ss://` 分享链接自动生成最小 Clash 配置时，现在会启用 `dns:`，并额外添加 `baidu.com`、`bdimg.com`、`bdstatic.com` 的直连规则，减少国内域名误走代理的情况。

- **改进旧版 macOS 的设置页图标兼容性** — 对不支持 SF Symbols 的系统补充了 fallback 图标，不再出现设置页顶部图标缺失的问题。

- **改进旧版 macOS 的菜单栏速率显示兼容性** — 状态栏速率视图在旧系统上增加了兼容 fallback，同时保留新系统使用的自绘实现。

---

[![Download ClashFX](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/clashfx/files/1.0.14/)
