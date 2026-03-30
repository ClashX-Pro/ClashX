## ClashFX 1.0.2

### Bug Fixes

- **Fix geosite download failure** — Bundle geosite.dat in the app so subscriptions with geosite rules work on first launch without needing GitHub access (#1)
- **Fix version check showing 10.14** — AppcastParser was collecting text from sibling XML elements (minimumSystemVersion). Version number is now correctly scoped (#2)
- **Fix dashboard broken after "Update UI"** — Clear all WKWebView data types including ServiceWorker registrations on launch. Add upgrade_ui JS bridge handler to safely reset dashboard from bundled files (#3)

### Improvements

- **Auto-notify websites on release** — New releases automatically update version numbers on clashfx.com and clashx.tech via repository_dispatch

---

### 修复

- **修复 geosite 下载失败** — 内置 geosite.dat，首次添加含 geosite 规则的订阅不再需要先连上代理 (#1)
- **修复版本检查显示 10.14** — AppcastParser 误采集了 minimumSystemVersion 的文本，现已正确限定采集范围 (#2)
- **修复"更新 UI"后控制台损坏** — 启动时清理所有 WebView 缓存（含 ServiceWorker），并拦截 upgrade_ui 操作安全重置 dashboard (#3)

### 改进

- **发版自动更新网站** — 新版本发布后自动更新 clashfx.com 和 clashx.tech 上的版本号
