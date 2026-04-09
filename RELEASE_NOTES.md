## ClashFX 1.0.8

### Bug Fixes

- **Fix remote config import rejecting proxy-provider-only configs** — Configs that use only `proxy-providers` (without inline `proxies`) were incorrectly rejected with "Remote Config Format Error". These configs work fine in other Clash clients. The overly strict proxy count check has been removed, aligning remote config validation with local config loading behavior. Fixes #12

---

### Bug 修复

- **修复远程配置导入误拒仅含 proxy-providers 的配置** — 仅使用 `proxy-providers`（无内联 `proxies`）的配置会被错误拒绝并显示"格式错误"，但同样的配置在其他 Clash 客户端可正常使用。已移除过于严格的代理数量检查，使远程配置校验与本地加载行为保持一致。修复 #12
