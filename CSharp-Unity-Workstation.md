# Emacs C# / Unity 工作站

这套配置让 C# 独立使用 `lsp-mode`，其他语言继续沿用原有 Eglot。默认
语言服务器是稳定版 `csharp-ls`，并保留按项目切换官方 Roslyn Language
Server 的能力。

## Unity 里的一次性设置

打开 `Edit > Preferences > External Tools`：

1. 执行 `M-x my/unity-external-editor-settings`，把复制出来的程序和参数填入
   `External Script Editor` / `External Script Editor Args`。
2. 参数应为 `--no-wait +$(Line) "$(File)"`。
3. 勾选 `Editor Attaching`，否则 DAP 能连接但断点不会命中。
4. 确保需要的 `.csproj` 类型已勾选，然后执行 `Regenerate project files`。

Emacs 启动时会自动启动 server，Unity 双击脚本后会复用现有 Emacs 实例。

## 常用入口

- `C-c u`：Unity 总菜单（启动编辑器、日志、解决方案、测试、构建、调试）。
- `C-c l`：C# LSP 命令前缀。
  - `C-c l b`：按项目切换 `csharp-ls` / `csharp-roslyn`。
  - `C-c l U`：选择项目的 `.sln`。
  - `C-c l R`：重启当前 C# workspace。
  - `C-c l F`：仅为当前缓冲区切换保存时格式化。
  - `C-c l u`：临时切换 `lsp-ui` 鼠标文档浮窗；不会开启行尾提示。
  - `C-c l ?`：C# 环境诊断。
- `TAB`：Corfu 候选存在时接受当前候选，Yasnippet 活跃时展开或跳到下一字段，
  其余时候在 C# 中移动到下一个宽度为 4 的逻辑制表位（文件实际保存空格）。
  缩进区的 `Backspace` 一次退回一个逻辑制表位。
- `C-c d`：调试命令前缀。
  - `C-c d b`：切换断点。
  - `C-c d a`：附加到正在运行的 Unity Editor。
  - `C-c d c/n/i/o`：继续 / 单步越过 / 单步进入 / 单步跳出。
  - `C-c d e`：求值，`C-c d q`：断开调试。
- `C-c n`：普通 SDK-style .NET 项目的 restore/build/test/run/debug。

## Unity 断点调试顺序

1. 用 Unity 打开项目并等待脚本编译完成。
2. 在 Emacs 打开 `.cs` 文件，等待 LSP 初始化。
3. 光标停在可执行代码行，按 `C-c d b` 设置断点。
4. 按 `C-c d a` 附加到 Unity Editor。
5. 在 Unity 中触发该代码；DAP 面板会显示调用栈、局部变量和断点。

重新安装调试器时可执行 `M-x my/unity-debug-setup`。普通 .NET 调试器的
安装命令是 `M-x my/dotnet-debug-setup`。

## Unity 项目和自动化

项目根目录由 `Assets/`、`Packages/`、`ProjectSettings/` 三个目录识别，
因此没有 `.git` 的 Plastic SCM 项目也能使用 `project.el`。配置会跳过
`Library/`、`Temp/`、`Logs/`、`Build/` 等大型生成目录。

`C-c u t` 通过 Unity Test Runner 的批处理接口运行 EditMode/PlayMode 测试；
`C-c u b` 运行项目中已有的静态 `-executeMethod` 构建入口。同一个项目被
Unity Editor 占用时，批处理实例通常无法打开它，因此先关闭对应编辑器实例。

默认配置以输入流畅为优先：保留补全、跳转、Flymake 诊断和签名提示，关闭
`lsp-ui` 行尾覆盖层、内联提示、Code Lens、语义着色、光标符号高亮和输入时
格式化。Corfu 在候选旁显示类型图标，并延迟显示候选文档；需要额外的鼠标悬停
文档浮窗时，可在当前 C# 缓冲区按 `C-c l u` 临时打开。

## 诊断

- `M-x my/csharp-doctor`：后端、solution、LSP、Tree-sitter 状态。
- `M-x my/unity-status`：项目、Unity 版本、编辑器路径、solution 状态。
- `M-x lsp-workspace-show-log`：语言服务器日志。
- `M-x dap-debug`：查看所有已注册的调试模板。

当前 Unity DAP 路径使用 `dap-mode` 自带的 `dap-unity` 集成和
`Unity.unity-debug` 适配器。它适合当前安装的 Unity 2021/2022；适配器上游
已经归档，未来升级到新的 Unity 大版本时应先做一次实际断点验证。
