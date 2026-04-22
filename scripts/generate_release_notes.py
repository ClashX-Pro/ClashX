#!/usr/bin/env python3
"""
Generate bilingual (EN/ZH) release notes from conventional commits.
Usage: python3 generate_release_notes.py <tag> <output-file>
"""
import subprocess, sys, re

TYPES = {
    "fix": ("Bug Fixes", "问题修复"),
    "feat": ("New Features", "新功能"),
    "perf": ("Performance Improvements", "性能优化"),
    "refactor": ("Refactoring", "代码重构"),
}

SKIP_TYPES = {"ci", "chore", "docs", "style", "test", "build", "release"}

CN_VERBS = {
    "fix": "修复",
    "add": "添加",
    "update": "更新",
    "replace": "替换",
    "remove": "移除",
    "delete": "删除",
    "skip": "跳过",
    "preserve": "保留",
    "simplify": "简化",
    "improve": "改进",
    "support": "支持",
    "enable": "启用",
    "disable": "禁用",
    "prevent": "防止",
    "allow": "允许",
    "correct": "修正",
    "handle": "处理",
    "bump": "升级",
    "automate": "自动化",
    "optimize": "优化",
    "resolve": "解决",
    "avoid": "避免",
    "reduce": "降低",
    "revert": "回退",
    "migrate": "迁移",
    "rename": "重命名",
    "move": "移动",
    "clean": "清理",
    "reset": "重置",
    "restore": "恢复",
    "implement": "实现",
    "use": "使用",
    "set": "设置",
    "ensure": "确保",
}

CN_TERMS = [
    ("generated compatibility configs", "生成的兼容配置"),
    ("compatibility configs", "兼容配置"),
    ("compatibility config", "兼容配置"),
    ("compatibility", "兼容性"),
    ("geosite template", "geosite 模板"),
    ("status ui", "状态界面"),
    ("older macos", "旧版 macOS"),
    ("macos catalina", "macOS Catalina"),
    ("go bridge", "Go 桥接层"),
    ("dreamacro/clash", "Dreamacro/clash"),
    ("mihomo", "mihomo"),
    ("ss-2022", "SS-2022"),
    ("shadowsocks-2022", "SS-2022"),
    ("cipher not supported", "不支持的加密算法"),
    ("cipher", "加密算法"),
    ("config home dir", "配置目录"),
    ("home dir", "配置目录"),
    ("home directory", "配置目录"),
    ("config directory", "配置目录"),
    ("no such file or directory", "找不到文件"),
    ("backward compatibility", "向后兼容"),
    ("subscribe", "订阅"),
    ("subscription import", "订阅导入"),
    ("user-agent", "User-Agent"),
    ("high cpu usage", "高 CPU 占用"),
    ("high cpu", "高 CPU 占用"),
    ("cpu usage", "CPU 占用"),
    ("infinite redraw loop", "无限重绘循环"),
    ("redraw loop", "重绘循环"),
    ("infinite loop", "无限循环"),
    ("rendering loop", "渲染循环"),
    ("external displays", "外接显示器"),
    ("external display", "外接显示器"),
    ("port availability check", "端口可用性检查"),
    ("port conflict", "端口冲突"),
    ("port fallback", "端口回退"),
    ("config reloads", "配置重载"),
    ("config reload", "配置重载"),
    ("auto-update", "自动更新"),
    ("false update prompt", "误报更新提示"),
    ("false sparkle update prompt", "误报 Sparkle 更新弹窗"),
    ("update prompt", "更新弹窗"),
    ("status bar", "状态栏"),
    ("menu bar", "菜单栏"),
    ("dashboard ui path", "仪表盘 UI 路径"),
    ("dashboard", "仪表盘"),
    ("system proxy", "系统代理"),
    ("proxy rule", "代理规则"),
    ("proxy", "代理"),
    ("subscription", "订阅"),
    ("crash on launch", "启动崩溃"),
    ("crash", "崩溃"),
    ("memory leak", "内存泄漏"),
    ("memory usage", "内存占用"),
    ("on startup", "启动时"),
    ("on launch", "启动时"),
    ("at startup", "启动时"),
    ("network", "网络"),
    ("connection", "连接"),
    ("speed label", "速度标签"),
    ("currently running instance", "当前运行的实例"),
    ("running instance", "运行中的实例"),
    ("custom draw view", "自定义绘制视图"),
    ("yaml indentation", "YAML 缩进"),
    ("build phase", "构建阶段"),
    ("dead link", "失效链接"),
    ("signing key", "签名密钥"),
    ("appcast update heredoc", "appcast 更新脚本"),
    ("appcast in ci", "CI 中的 appcast"),
    ("in ci", "CI 流程中"),
    ("port", "端口"),
]

CN_CONNECTORS = [
    (r"\band\b", "并"),
    (r"\bacross\b", "跨"),
    (r"\bwhen\b", "当"),
    (r"\bvia\b", "通过"),
    (r"\bto\b", "为"),
    (r"\bmatches\b", "匹配"),
]


def get_previous_tag(current):
    r = subprocess.run(
        ["git", "tag", "--sort=-version:refname"],
        capture_output=True,
        text=True,
        check=True,
    )
    tags = [t.strip() for t in r.stdout.strip().split("\n") if t.strip()]
    for i, t in enumerate(tags):
        if t == current and i + 1 < len(tags):
            return tags[i + 1]
    return None


def get_commits(from_tag, to_tag):
    SEP = "---@@COMMIT@@---"
    range_spec = f"{from_tag}..{to_tag}" if from_tag else to_tag
    fmt = f"%s{SEP}%b{SEP}"
    r = subprocess.run(
        ["git", "log", range_spec, f"--pretty=format:{fmt}"],
        capture_output=True,
        text=True,
        check=True,
    )
    raw = r.stdout
    if not raw.strip():
        return []
    parts = raw.split(SEP)
    commits = []
    i = 0
    while i + 1 < len(parts):
        subject = parts[i].strip().lstrip("\n")
        body = parts[i + 1].strip()
        if subject:
            commits.append((subject, body))
        i += 2
    return commits


def parse_type(subject):
    m = re.match(r"^(\w+)(?:\(.+?\))?:\s*(.+)$", subject)
    if m:
        return m.group(1).lower(), m.group(2).strip()
    return None, subject.strip()


def _apply_terms(text):
    """Replace known English terms with Chinese equivalents."""
    for en, zh in CN_TERMS:
        text = re.sub(re.escape(en), zh, text, flags=re.IGNORECASE)
    return text


def _apply_connectors(text):
    """Replace English connectors/prepositions for cleaner mixed output."""
    for pattern, zh in CN_CONNECTORS:
        text = re.sub(pattern, zh, text, flags=re.IGNORECASE)
    return text


def _ensure_cjk_spacing(text):
    """Ensure space between CJK and ASCII characters for readability."""
    text = re.sub(r"([\u4e00-\u9fff])([A-Za-z0-9])", r"\1 \2", text)
    text = re.sub(r"([A-Za-z0-9])([\u4e00-\u9fff])", r"\1 \2", text)
    return re.sub(r"\s{2,}", " ", text).strip()


def _full_translate(text):
    """Apply all translation layers: terms → verbs → connectors → cleanup."""
    s = _apply_terms(text)
    words = s.split()
    for i, w in enumerate(words):
        if w.lower() in CN_VERBS:
            words[i] = CN_VERBS[w.lower()]
    s = " ".join(words)
    s = _apply_connectors(s)
    return _ensure_cjk_spacing(s)


def _chinese_ratio(text):
    """Return ratio of CJK characters to total non-space characters."""
    non_space = re.sub(r"\s", "", text)
    if not non_space:
        return 0
    cjk = len(re.findall(r"[\u4e00-\u9fff]", non_space))
    return cjk / len(non_space)


def _extract_key_terms(text):
    """Extract known Chinese terms from text for fallback summary."""
    found = []
    lower = text.lower()
    for en, zh in CN_TERMS:
        if en in lower:
            found.append(zh)
            lower = lower.replace(en, "", 1)
    return list(dict.fromkeys(found))


def _smart_translate(text, prefix):
    """Translate with quality check; use condensed summary if quality is low."""
    full = _full_translate(text)
    if _chinese_ratio(full) >= 0.15:
        return f"{prefix}{full}"
    terms = _extract_key_terms(text)
    if terms:
        return f"{prefix}{' / '.join(terms)}相关问题"
    return f"{prefix}{_apply_terms(text)}"


def to_chinese(text, commit_type="fix"):
    """Best-effort Chinese summary from English commit subject."""
    s = re.sub(r"\s*\(#\d+\)\s*$", "", text).strip()

    if commit_type == "fix":
        # "restore/upgrade/... X" -> "<verb><translated X>相关问题"
        m = re.match(r"(\w+)\s+(.+)$", s, re.I)
        if m and m.group(1).lower() in CN_VERBS:
            verb = CN_VERBS[m.group(1).lower()]
            body = _full_translate(m.group(2))
            if _chinese_ratio(body) >= 0.15:
                return f"{verb}{body}相关问题"
            terms = _extract_key_terms(m.group(2))
            if terms:
                return f"{verb}{' / '.join(terms)}相关问题"
            return f"修复{_apply_terms(s)}相关问题"

        # "do X to fix/resolve/prevent Y" → "修复 Y 的问题"
        m = re.search(r"to (?:fix|resolve|prevent|avoid)\s+(.+)$", s, re.I)
        if m:
            problem = _apply_terms(m.group(1))
            return f"修复{problem}的问题"

        # "fix X when/on/if Y" → "修复 Y 时 X 的问题"
        m = re.match(
            r"(?:fix|resolve|correct)\s+(.+?)(?:\s+when\s+|\s+on\s+|\s+if\s+)(.+)$",
            s,
            re.I,
        )
        if m:
            issue = _apply_terms(m.group(1))
            context = _apply_terms(m.group(2))
            return f"修复{context}时{issue}的问题"

        # "fix/correct X in/of Y" → "修复 Y 中 X 的问题"
        m = re.match(
            r"(?:fix|resolve|correct)\s+(.+?)\s+(?:in|of)\s+(.+)$", s, re.I
        )
        if m:
            issue = _apply_terms(m.group(1))
            scope = _apply_terms(m.group(2))
            return f"修复 {scope} 中{issue}的问题"

        # "fix X" → "修复 X 的问题"
        m = re.match(r"(?:fix|resolve|correct)\s+(.+)$", s, re.I)
        if m:
            translated = _apply_terms(m.group(1))
            if _chinese_ratio(translated) >= 0.15:
                return f"修复{translated}的问题"
            terms = _extract_key_terms(m.group(1))
            if terms:
                return f"修复{' / '.join(terms)}相关问题"
            return f"修复{translated}的问题"

        # Fallback
        return _smart_translate(s, "修复: ")

    if commit_type == "feat":
        # "upgrade X to Y" -> "升级X为Y"
        m = re.match(r"(?:upgrade|update)\s+(.+?)\s+to\s+(.+)$", s, re.I)
        if m:
            left = _full_translate(m.group(1))
            right = _full_translate(m.group(2))
            return f"升级{left}为{right}"
        m = re.match(r"(?:add|implement|introduce)\s+(.+)$", s, re.I)
        if m:
            return _smart_translate(m.group(1), "新增")
        m = re.match(r"(\w+)\s+(.+)$", s, re.I)
        if m and m.group(1).lower() in CN_VERBS:
            verb = CN_VERBS[m.group(1).lower()]
            # Ensure natural CJK concatenation for feature verb phrases.
            return _smart_translate(m.group(2), f"{verb}")
        return _smart_translate(s, "")

    if commit_type == "perf":
        return _smart_translate(s, "优化")

    if commit_type == "refactor":
        return _smart_translate(s, "重构")

    return _full_translate(s)


def clean_title(text):
    return re.sub(r"\s*\(#\d+\)\s*$", "", text).strip()


def first_paragraph(body):
    """Extract first meaningful paragraph from commit body."""
    lines = []
    for line in body.split("\n"):
        stripped = line.strip()
        if stripped.startswith("- ") or stripped.startswith("* "):
            break
        if stripped.startswith("Closes #") or stripped.startswith("Made-with:"):
            break
        if not stripped and lines:
            break
        if stripped:
            lines.append(stripped)
    return " ".join(lines) if lines else ""


def generate(tag, categorized):
    lines = [f"## ClashX v{tag}", ""]

    has_content = False
    for ctype in TYPES:
        items = categorized.get(ctype)
        if not items:
            continue
        has_content = True
        en_cat, zh_cat = TYPES[ctype]
        lines.append(f"### {en_cat} / {zh_cat}")
        lines.append("")
        for title_rest, body in items:
            en_title = clean_title(title_rest)
            cn_summary = _ensure_cjk_spacing(to_chinese(title_rest, ctype))
            en_desc = first_paragraph(body)

            lines.append(f"- **{en_title}**")
            if en_desc:
                lines.append(f"  {en_desc}")
                lines.append("")
                lines.append(f"  {cn_summary}")
            else:
                lines.append(f"  {cn_summary}")
            lines.append("")

    if not has_content:
        lines.append("Maintenance release / 维护版本更新。")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("Minimum system requirement: macOS 10.14.")
    lines.append("最低系统要求：macOS 10.14。")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <tag> [output-file]", file=sys.stderr)
        sys.exit(1)

    tag = sys.argv[1]
    output = sys.argv[2] if len(sys.argv) > 2 else None

    prev = get_previous_tag(tag)
    commits = get_commits(prev, tag)

    categorized = {}
    for subject, body in commits:
        ctype, rest = parse_type(subject)
        if ctype in SKIP_TYPES or ctype is None:
            continue
        if ctype not in TYPES:
            continue
        categorized.setdefault(ctype, []).append((rest, body))

    notes = generate(tag, categorized)

    if output:
        with open(output, "w") as f:
            f.write(notes)
        print(f"Release notes written to {output}")
    else:
        print(notes)


if __name__ == "__main__":
    main()
