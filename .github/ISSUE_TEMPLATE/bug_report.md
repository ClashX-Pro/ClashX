---
name: Bug report
about: Create a report to help us improve
title: "[Bug]"
labels: ''
assignees: ''

---

<!-- The English version is available. -->
感谢你向 ClashX 提交 issue！
在提交之前，请确认：

- [ ] 我已经在 [Issue Tracker](……/) 中找过我要提出的问题
- [ ] 这是 ClashX UI层面的问题，并非 Clash Core 的问题(例如xx软件连不上，无法连接特定服务器等)。其他 Clash 衍生版本没有次问题。
- [ ] 如果你可以自己 debug 并解决的话，提交 PR 吧！

请注意，如果你并没有遵照这个 issue template 填写内容，我们将直接关闭这个 issue。

<!--
Thanks for submitting an issue towards the ClashX !
But before so, please do the following checklist:

- [ ] Is this something you can **debug and fix**? Send a pull request! Bug fixes and documentation fixes are welcome.
- [ ] Your issue may already be reported! Please search on the [issue tracker](……/) before creating one.
- [ ] This is an issue related to the ClashX, the other derivatives of Clash does not have this issue. It's not a issue of Clash Core

Please understand that we close issues that fail to follow the issue template.
-->

我都确认过了，我要继续提交。
<!-- None of the above, create a bug report -->
------------------------------------------------------------------

请附上任何可以帮助我们解决这个问题的信息，如果我们收到的信息不足，我们将对这个 issue 加上 *Needs more information* 标记并在收到更多资讯之前关闭 issue。
<!-- Make sure to add **all the information needed to understand the bug** so that someone can help. If the info is missing we'll add the 'Needs more information' label and close the issue until there is enough information. -->

### clashX config
<!--
在下方附上 ClashX 脱敏后配置文件的内容
Paste the ClashX configuration below.
-->
```
……
```

### ClashX log
<!--
在下方附上 ClashX 的日志，log level 最好使用 DEBUG。点击菜单栏->帮助->显示日志
Paste the ClashX log below with the log level set to `DEBUG`.
-->
```
……
```


### ClashX Crash log
<!--
在下方附上 ClashX 的系统崩溃日志，位于 ~/Library/Logs/DiagnosticReports
Paste the ClashX system crash log. Located in ~/Library/Logs/DiagnosticReports
-->
```
……
```



### 环境 Environment
……
* 使用者的操作系统 (the OS running on the client)
……
* 网路环境或拓扑 (network conditions/topology)
……
* ISP 有没有进行 DNS 污染 (is your ISP performing DNS pollution?)
……
* 其他
……

### 说明 Description

<!--
请详细、清晰地表达你要提出的论述，例如这个问题如何影响到你？你想实现什么功能？
-->

### 重现问题的具体布骤 Steps to Reproduce

1. [First Step]
2. [Second Step]
3. ……

**我预期会发生……？**
<!-- **Expected behavior:** [What you expected to happen] -->

**实际上发生了什麽？**
<!-- **Actual behavior:** [What actually happened] -->

### 可能的解决方案 Possible Solution
<!-- 此项非必须，但是如果你有想法的话欢迎提出。 -->
<!-- Not obligatory, but suggest a fix/reason for the bug, -->
<!-- or ideas how to implement the addition or change -->

### 更多信息 More Information
