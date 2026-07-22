# Emacs 工作流与快捷键使用说明

这份手册适用于当前 `.emacs.d` 配置，重点是日常编辑、项目导航以及 C# / Unity
开发。一次性的 Unity External Editor 和调试器安装方法见
[CSharp-Unity-Workstation.md](./CSharp-Unity-Workstation.md)。

不必一次记住所有快捷键。当前配置启用了 Which-Key：按下 `C-c w`、`C-c !`、
`C-c d` 等前缀后停留约 0.45 秒，Emacs 会显示后续可用按键。

## 1. 先理解 Emacs 的按键写法

| 写法 | 含义 |
| --- | --- |
| `C-x` | 按住 Ctrl，再按 x |
| `M-x` | 按住 Alt，再按 x；Emacs 把 Alt 称为 Meta |
| `S-x` | 按住 Shift，再按 x |
| `C-c w p` | 依次按 `Ctrl+c`、`w`、`p`，不是同时按四个键 |
| `RET` | 回车 |
| `DEL` | Backspace |
| `SPC` | 空格 |

大写子键和小写子键是不同命令。例如 `C-c l U` 需要最后按 `Shift+u`，而
`C-c l u` 不需要 Shift。

### 无论如何先记住这五个

| 快捷键 | 用途 |
| --- | --- |
| `C-g` | 取消当前命令、退出提示框；不知道怎么办时先按它 |
| `M-x` | 按命令名称执行任何 Emacs 命令 |
| `C-h k` | 查询一个快捷键的作用；按完后再按想查询的键 |
| `C-h m` | 查看当前文件类型（Major Mode）的帮助 |
| `C-h B` | 查看当前缓冲区实际生效的快捷键 |

## 2. 十分钟快速上手

第一次使用时，按下面顺序练一遍即可：

1. 启动 Emacs，在 Dashboard 按 `p` 选择项目，或者按 `C-c w p` 把项目作为
   独立工作区打开。
2. 按 `C-x C-f` 打开文件，按 `C-x C-s` 保存。
3. 在文件中按 `C-s` 搜索当前文件内容；输入文字后用上下方向键选择，按
   `RET` 跳转，按 `C-g` 取消。
4. 在项目中按 `C-c r` 搜索所有文件。Unity 的 `Library/`、`Temp/`、`Logs/`
   等生成目录会被忽略。
5. 在 C# 中输入至少两个字符，等待补全列表出现；用上下方向键选择，按
   `TAB` 或 `RET` 接受。
6. 把光标放在变量或函数上，按 `M-.` 跳到定义，按 `M-,` 返回。
7. 按 `C-c ! n` 跳到下一个诊断，按 `C-c ! p` 返回上一个诊断。
8. 在 Unity 项目中按 `C-c u` 打开 Unity 总菜单。
9. 按 `C-c l ?` 查看当前 C# 语言服务器状态。
10. 如果忘记后续键，按下命令前缀后稍等 Which-Key 提示。

## 3. 打开、保存和基础编辑

| 快捷键 | 用途 |
| --- | --- |
| `C-x C-f` | 打开或新建文件 |
| `C-x C-s` | 保存当前文件 |
| `C-x k` | 关闭当前缓冲区；不会直接退出 Emacs |
| `C-x C-b` | 打开 Ibuffer 缓冲区管理器 |
| `C-/` | 撤销 |
| `C-SPC` | 设置选区起点，然后移动光标形成选区 |
| `C-w` | 剪切选区 |
| `M-w` | 复制选区 |
| `C-y` | 粘贴 |
| `M-y` | 浏览并选择剪贴历史 |

Emacs 中“缓冲区”可以理解为已打开的文件、日志、终端或帮助页面。关闭缓冲区
不等于关闭对应磁盘文件。

## 4. 浮层选择列表怎么操作

`M-x`、`C-s`、`C-x b`、查找文件和项目搜索都会使用顶部居中的 Vertico
选择面板。

| 按键 | 用途 |
| --- | --- |
| 上、下方向键 | 移动候选项 |
| `RET` | 确认当前候选；选择目录时进入目录 |
| `TAB` | 把当前候选补入输入框 |
| `DEL` | 删除一个字符；文件路径为空时返回上级目录 |
| `M-DEL` | 删除一段路径 |
| `C-g` | 取消并关闭面板 |
| `C-.` | 对当前候选打开 Embark 操作菜单 |

搜索采用 Orderless 匹配。比如输入 `game inst`，可以匹配同时包含 `game` 与
`inst` 的候选，不要求两个片段连续出现。这通常比输入完整名称更快。

## 5. Dashboard 启动页

Dashboard 是启动后的入口页。光标不需要移动到按钮上，直接按键即可：

| 按键 | 用途 |
| --- | --- |
| `p` | 选择项目 |
| `f` | 打开文件 |
| `r` | 最近文件 |
| `a` | Org Agenda |
| `t` | 今天的日程 |
| `w` | 本周日程 |
| `c` | Org Capture |
| `e` | 打开 Emacs 配置 |
| `g` | 刷新 Dashboard |

## 6. 文件、符号和项目搜索

| 快捷键 | 范围 | 用途 |
| --- | --- | --- |
| `C-s` | 当前文件 | 实时搜索行内容 |
| `C-c r` | 当前项目 | 使用 Ripgrep 搜索项目文本；最常用 |
| `C-c g` | 当前目录 | 使用 Grep 搜索 |
| `M-g i` | 当前文件 | 按类、方法、字段等符号跳转 |
| `M-g g` | 当前文件 | 跳到指定行号 |
| `C-x b` | 当前工作区 | 切换缓冲区 |
| `C-x 4 b` | 其他窗口 | 在另一个窗口打开缓冲区 |
| `C-x 5 b` | 其他 Frame | 在另一个 Emacs Frame 打开缓冲区 |
| `C-x r b` | 全局 | 打开书签 |
| `C-x g` | 当前项目 | 打开 Magit Git 状态页 |

在 Consult 搜索列表中，上下移动会预览结果，`RET` 打开，`C-g` 取消。项目文件
很多时，优先使用 `C-c r`，不要手动搜索 Unity 的 `Library/`。

## 7. 项目工作区与窗口

当前“工作区”使用 Emacs 内置 Tab Bar。一个 Tab 通常对应一个项目，而不是一个
文件。只有一个工作区时 Tab Bar 会自动隐藏。

### 工作区前缀 `C-c w`

| 快捷键 | 用途 |
| --- | --- |
| `C-c w p` | 选择项目，并在同名工作区中打开 |
| `C-c w n` | 新建空工作区并打开 Dashboard |
| `C-c w w` | 按名称切换工作区 |
| `C-c w [` / `C-c w ]` | 上一个 / 下一个工作区 |
| `C-c w r` | 重命名当前工作区 |
| `C-c w x` | 关闭当前工作区 |
| `C-c w u` | 恢复刚关闭的工作区 |
| `C-c w z` / `C-c w Z` | 撤销 / 重做窗口布局变化 |
| `C-c w h/j/k/l` | 移动到左 / 下 / 上 / 右窗口 |
| `C-c w H/J/K/L` | 把当前窗口与对应方向窗口交换 |

重复执行 `C-c w p` 打开同一个项目时，会复用同名工作区，不会不断创建重复 Tab。

### Emacs 原生窗口键

| 快捷键 | 用途 |
| --- | --- |
| `C-x 2` | 上下分割窗口 |
| `C-x 3` | 左右分割窗口 |
| `C-x o` | 切换到另一个窗口 |
| `C-x 0` | 关闭当前窗口，不关闭缓冲区 |
| `C-x 1` | 只保留当前窗口 |

## 8. C# 编辑、缩进和补全

打开 `.cs` 文件后会自动启用 Tree-sitter（可用时）、Flymake、Corfu 和
`lsp-mode`。默认 C# 后端是稳定版 `csharp-ls`。

### TAB 和 Backspace 的实际规则

当前配置使用“逻辑制表位”，文件中实际保存的是空格，不是 `\t` 字符：

1. 补全列表出现时，`TAB` 接受当前候选。
2. Yasnippet 已展开时，`TAB` 跳到下一个字段。
3. 可以展开 Snippet 时，`TAB` 展开 Snippet。
4. 其他情况下，C# 中的 `TAB` 插入空格直到下一个 4 列制表位。
5. 光标位于行首缩进区时，Backspace 一次退回一个 4 列逻辑制表位。
6. 光标位于代码正文时，Backspace 仍只删除一个字符。

因此它的手感接近 VS Code 的“四空格 Tab”，同时避免在 C# 文件中混入真实
Tab 字符。

### Corfu 代码补全

补全通常在输入两个字符并等待约 0.25 秒后自动出现：

| 按键 | 用途 |
| --- | --- |
| 上、下方向键 | 选择候选 |
| `M-n` / `M-p` | 下一个 / 上一个候选 |
| `TAB` | 完成并接受当前候选 |
| `RET` | 插入当前候选 |
| `C-g` | 关闭补全 |
| `M-TAB` 或 `C-M-i` | 手动请求当前位置补全 |

Windows 通常会拦截 `Alt+Tab`，所以手动补全优先使用 `C-M-i`，也就是
`Ctrl+Alt+i`。候选旁会显示类型图标；停留约 0.65 秒后显示候选文档。

### 跳转和查找引用

这些 Xref 快捷键在 C#、Java、C/C++ 等语言中通用：

| 快捷键 | 用途 |
| --- | --- |
| `M-.` | 跳到定义 |
| `M-?` | 查找引用 |
| `M-,` | 返回跳转前的位置 |

## 9. C# 语言服务器命令

C# 使用 `lsp-mode`；其他语言主要使用 Eglot。两者都占用 `C-c l` 前缀，但
后续按键不同。先看当前文件是否是 `.cs`，再选择下面对应表格。

### C# / Unity 中的 `C-c l`

| 快捷键 | 用途 |
| --- | --- |
| `C-c l ?` | 打开 C# Doctor，查看项目、Solution、后端和 LSP 状态 |
| `C-c l U` | 选择并记住当前 Unity 项目的 `.sln` / `.slnx` |
| `C-c l R` | 重启当前项目的 C# Workspace |
| `C-c l b` | 为当前项目切换 `csharp-ls` / `csharp-roslyn` |
| `C-c l F` | 为当前 C# 缓冲区切换“保存时格式化” |
| `C-c l u` | 临时开关较重的鼠标悬停文档；默认关闭以保持流畅 |
| `C-c l a a` | 执行 Code Action |
| `C-c l r r` | 重命名符号 |
| `C-c l = =` | 格式化整个缓冲区 |
| `C-c l = r` | 格式化选区 |

注意 `C-c l U` 与 `C-c l u` 不同。前者选择 Unity Solution，后者开关可选的
`lsp-ui` 文档浮窗。

### Java、C/C++ 等 Eglot 缓冲区中的 `C-c l`

| 快捷键 | 用途 |
| --- | --- |
| `C-c l a` | Code Action |
| `C-c l r` | 重命名符号 |
| `C-c l f` | 格式化缓冲区 |
| `C-c l d` | 跳到定义 |
| `C-c l D` | 查找引用 |
| `C-c l q` | 关闭 Eglot |
| `C-c l R` | 重连 Eglot |
| `C-c l t` | 开关当前缓冲区的 Eglot |

## 10. Flymake 诊断

错误和警告使用下划线与右侧 Fringe 图标显示。光标停在诊断位置约 0.45 秒后，
详细信息会在光标附近弹出，不再把长串蓝色文字一直放在行尾。

### 诊断前缀 `C-c !`

| 快捷键 | 用途 |
| --- | --- |
| `C-c ! n` | 下一个诊断 |
| `C-c ! p` | 上一个诊断 |
| `C-c ! d` | 在底部临时显示光标处诊断 |
| `C-c ! l` | 用 Consult 列出当前缓冲区诊断 |
| `C-c ! b` | 打开当前缓冲区诊断列表 |
| `C-c ! P` | 打开项目诊断列表 |
| `C-c ! s` | 立即重新运行 Flymake |
| `M-g e` | 另一种打开 Consult 诊断列表的方式 |

弹层只有在光标确实位于诊断范围内时才出现。如果想强制查看，请使用
`C-c ! d` 或 `C-c ! l`。

## 11. Unity 日常工作流

配置会通过 `Assets/`、`Packages/`、`ProjectSettings/` 识别 Unity 根目录，
不要求项目必须使用 Git，所以 Plastic SCM 项目也能使用工作区和项目搜索。

### 推荐打开方式

1. 从 Dashboard 按 `p`，或按 `C-c w p` 选择 Unity 项目根目录。
2. 打开 `Assets/` 下的 `.cs` 文件。
3. 等待 C# LSP 完成首次加载；大型项目第一次索引会明显更久。
4. 按 `C-c l ?`，确认 `LSP active` 为 `yes`。
5. 如果项目有多个 Solution，用 `C-c l U` 明确选择。

Unity 已配置 External Script Editor 后，也可以直接在 Unity 中双击脚本；
`emacsclient` 会把文件送到现有 Emacs 实例。

### Unity 总菜单 `C-c u`

按 `C-c u` 后会立即出现菜单，再按一个子键：

| 子键 | 用途 |
| --- | --- |
| `o` | 用匹配项目版本的 Unity Editor 打开项目 |
| `l` | 在另一窗口打开并持续跟随 `Editor.log` |
| `s` | 选择 Solution |
| `r` | 重载 C# LSP Solution |
| `t` | 运行 EditMode / PlayMode / 全部测试 |
| `b` | 调用项目中的静态 `-executeMethod` 构建方法 |
| `e` | 复制 Unity External Editor 设置 |
| `d` | 打开 Unity Scripting API 文档 |
| `i` | 首次安装 Unity 调试适配器 |
| `a` | 附加到正在运行的 Unity Editor |
| `?` | 查看 Unity 项目状态 |

Unity Test / Build 使用新的 BatchMode Unity 进程。同一项目正被 Unity Editor
占用时通常无法再次打开，所以执行 `t` 或 `b` 前应先关闭对应 Editor 实例。

### Unity 补全读不到项目变量时

例如 `Instance` 没出现在补全列表，按以下顺序检查：

1. 确认文件位于正确 Unity 项目的 `Assets/` 下，而不是临时副本。
2. 在 Unity 的 External Tools 中执行 `Regenerate project files`。
3. 回到 Emacs，按 `C-c l ?` 查看 C# Doctor。
4. 如果 Solution 不正确，按 `C-c l U` 重新选择。
5. 按 `C-c l R` 重启 Workspace，并等待索引完成。
6. 在变量位置按 `C-M-i` 手动请求补全。
7. 仍然失败时执行 `M-x lsp-workspace-show-log` 查看服务器日志。

不要反复快速重启 LSP；大型 Unity Solution 每次重启都要重新载入，会让 Emacs
在一段时间内显得更卡。

## 12. Unity / .NET 调试

第一次调试前，需要在 Unity 的 External Tools 中勾选 `Editor Attaching`，并
执行一次 `C-c d u` 安装 Unity 调试适配器。

### 调试前缀 `C-c d`

| 快捷键 | 用途 |
| --- | --- |
| `C-c d u` | 安装 Unity 调试适配器；通常只需一次 |
| `C-c d N` | 安装普通 .NET 的 netcoredbg；通常只需一次 |
| `C-c d a` | 附加到运行中的 Unity Editor |
| `C-c d d` | 选择一个 DAP 调试模板 |
| `C-c d b` | 在当前行切换断点 |
| `C-c d B` | 删除全部断点 |
| `C-c d c` | 继续运行 |
| `C-c d n` | 单步越过 |
| `C-c d i` | 单步进入 |
| `C-c d o` | 单步跳出 |
| `C-c d e` | 对光标处表达式求值 |
| `C-c d h` | 打开 DAP Hydra 控制面板 |
| `C-c d q` | 断开调试 |

### 一次完整的 Unity 断点流程

1. 启动 Unity 并等待脚本编译完成。
2. 在 Emacs 中打开对应 `.cs` 文件。
3. 把光标放在可执行代码行，按 `C-c d b`。
4. 按 `C-c d a` 附加到 Unity。
5. 在 Unity 中触发代码。
6. 命中断点后使用 `C-c d n/i/o/c` 单步或继续。
7. 完成后按 `C-c d q` 断开。

## 13. 普通 .NET 项目

Unity 项目不应直接使用 `dotnet build/test/run`，因为 Unity 生成的 `.csproj`
不是权威构建入口；Unity 项目应使用 `C-c u` 菜单。

普通 SDK-style .NET 项目可使用：

| 快捷键或命令 | 用途 |
| --- | --- |
| `C-c n r` | `dotnet restore` |
| `M-x my/dotnet-build` | `dotnet build` |
| `C-c n t` | `dotnet test` |
| `C-c n x` | `dotnet run` |
| `C-c n d` | 选择 DAP 调试模板 |
| `C-c d N` | 安装 netcoredbg |

当前 `C-c n` 同时承载 Org-roam。最终生效的 `C-c n b` 是 Org-roam Buffer，
`C-c n i` 是插入 Org-roam 节点，所以普通 .NET Build 暂时使用
`M-x my/dotnet-build`。这是当前配置的已知按键重叠，不是命令失效。

## 14. Git、Org、Notion 和 Markdown

这些是可选工作流，不做 Unity 开发时可以暂时跳过。

### Git

| 快捷键 | 用途 |
| --- | --- |
| `C-x g` | 打开 Magit Status |

进入 Magit 后按 `?` 查看当前页面命令，按 `q` 返回。刚开始无需记忆 Magit 的
全部子键。

### Org / Org-roam

| 快捷键 | 用途 |
| --- | --- |
| `C-c a` | Org Agenda |
| `C-c c` | Org Capture |
| `C-c n f` | 查找 Org-roam 节点 |
| `C-c n i` | 在当前位置插入节点链接 |
| `C-c n c` | 捕获新节点 |
| `C-c n b` | 开关 Org-roam Buffer |
| `C-c n g` | 打开 Org-roam Graph |
| `C-c n l` | 保存 Org 链接 |

### Notion 镜像

| 快捷键 | 用途 |
| --- | --- |
| `C-c N s` | 拉取 Notion 任务 |
| `C-c N t` | 打开本地任务文件 |
| `C-c N o` | 打开光标处 Notion 页面 |
| `C-c N ?` | 查看认证帮助 |
| `C-c N k` | 保存 Token 到 macOS Keychain；Windows 不使用此项 |

### Markdown

在 Markdown 文件中使用 `C-c C-c` 命令前缀：

| 快捷键 | 用途 |
| --- | --- |
| `C-c C-c p` | 开关 Grip 预览 |
| `C-c C-c P` | 开关 Markdown Preview Mode |
| `C-c C-c t` | 生成目录 |

## 15. 界面开关

| 快捷键 | 用途 |
| --- | --- |
| `F6` | 在深色与浅色 Doom Theme 之间切换 |
| `F7` | 整体开关 Vertico / Flymake 浮层 |

部分键盘需要按 `Fn+F6` / `Fn+F7`。关闭 `F7` 后功能仍然存在，只是选择列表
退回原生 Minibuffer，诊断退回普通显示方式。

## 16. 常见问题

### 按键按错后 Emacs 一直等后续输入

按 `C-g`。它是 Emacs 的通用取消键。

### 输入后没有代码补全

先按 `C-M-i` 手动触发。如果只有文件名或普通单词，没有项目符号，再检查
`C-c l ?` 中的 LSP 状态与 Solution。

### TAB 没有插入四个空格

确认当前文件是 `.cs`，并且光标前没有正在显示的 Corfu 候选或活动 Snippet。
这两种情况下 `TAB` 会优先接受补全或跳转 Snippet 字段。普通文本中的 `TAB`
仍遵循对应 Major Mode 的缩进规则。

### Backspace 只删除了一个字符

一次删除四列只在 C# 行首缩进区生效。光标进入代码正文后会恢复普通的单字符
删除，这是为了避免误删代码。

### 诊断弹层没有出现

把光标移到有下划线的准确位置并停留约 0.45 秒，或直接按 `C-c ! d`。

### Emacs 在打开 Unity 工程后暂时变卡

首次载入 Solution 时语言服务器会读取大量 `.csproj` 和程序集引用。先等待
状态稳定；不要同时反复执行 `C-c l R`。默认配置已经关闭语义着色、Inlay Hint、
Code Lens、行尾 Sideline 和输入时格式化等较重功能。

### 不知道当前键到底执行什么

按 `C-h k` 后输入该快捷键，或按 `C-h B` 查看当前缓冲区实际绑定。Major Mode
和 Minor Mode 可以覆盖全局键，因此这两个帮助命令比静态列表更权威。

## 17. 建议优先记忆的快捷键清单

如果只想记一页，先记这些：

| 快捷键 | 用途 |
| --- | --- |
| `C-g` | 取消 |
| `M-x` | 按名称执行命令 |
| `C-x C-f` / `C-x C-s` | 打开 / 保存文件 |
| `C-s` | 搜索当前文件 |
| `C-c r` | 搜索当前项目 |
| `C-x b` | 切换缓冲区 |
| `C-c w p` | 在工作区中打开项目 |
| `M-.` / `M-,` | 跳到定义 / 返回 |
| `M-?` | 查找引用 |
| `TAB` | C# 补全、Snippet 或四空格逻辑缩进 |
| `C-M-i` | 手动请求代码补全 |
| `C-c ! n/p` | 下一个 / 上一个诊断 |
| `C-c l ?` | 查看 C# LSP 状态 |
| `C-c l R` | 重启 C# Workspace |
| `C-c u` | Unity 总菜单 |
| `C-c d b` / `C-c d a` | 设置断点 / 附加 Unity |
| `F6` / `F7` | 切换主题 / 浮层 |

遇到忘记的命令时，不必离开 Emacs：按前缀等待 Which-Key，或者用 `M-x` 搜索
命令名称。
