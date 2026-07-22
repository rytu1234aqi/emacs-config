;;; init.el --- stable Emacs config with Java/Eglot support -*- lexical-binding: t; -*-

;; 这份配置是在你现有 init.el 基础上整理而来：
;; - 保留：基础 UI、macOS 键位、Markdown、Tree-sitter、C/C++、C#、Ghostty/Codex 外部模块
;; - 清理：重复的 package 初始化、自定义区写入 init.el、未防护的 flycheck/clang-format 调用
;; - 新增：Vertico/Consult/Corfu 补全体系、Java Tree-sitter、eglot-java、Maven/Gradle 快捷命令

;;; -----------------------------------------------------------------------------
;;; 基础界面
;;; -----------------------------------------------------------------------------

(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq ring-bell-function #'ignore)

(when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode)   (menu-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(add-to-list 'default-frame-alist '(fullscreen . maximized))

(column-number-mode 1)
(show-paren-mode 1)
(setq show-paren-delay 0)

;; 行号和当前行高亮只用于编辑文本的缓冲区，避免拖慢大型特殊缓冲区。
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'hl-line-mode)

;;; -----------------------------------------------------------------------------
;;; 编辑行为
;;; -----------------------------------------------------------------------------

(defvar my/state-directory
  (expand-file-name "var/" user-emacs-directory)
  "Directory for generated state and recovery files.")

(let ((backup-dir (expand-file-name "backups/" my/state-directory))
      (auto-save-dir (expand-file-name "auto-save/" my/state-directory)))
  (dolist (dir (list my/state-directory backup-dir auto-save-dir))
    (make-directory dir t))
  (setq backup-directory-alist `(("." . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,auto-save-dir t))
        auto-save-list-file-prefix (expand-file-name ".saves-" auto-save-dir)))

(setq save-place-file (expand-file-name "places" my/state-directory)
      recentf-save-file (expand-file-name "recentf" my/state-directory)
      savehist-file (expand-file-name "history" my/state-directory)
      project-list-file (expand-file-name "projects" my/state-directory))

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default c-basic-offset 4)

(electric-pair-mode 1)
(delete-selection-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(savehist-mode 1)

(setq make-backup-files t
      auto-save-default t
      create-lockfiles t
      version-control t
      kept-new-versions 10
      kept-old-versions 2
      delete-old-versions t)

;; compile 原绑定 C-c c，改为 C-c C-k，把 C-c c 留给 org-capture
(global-set-key (kbd "C-c C-k") #'compile)
(global-set-key (kbd "C-x C-b") #'ibuffer)

;;; macOS 键位：Command 当 Meta，Option 当 Super
(when (eq system-type 'darwin)
  (setq ns-command-modifier 'meta)
  (setq ns-option-modifier 'super))

;;; -----------------------------------------------------------------------------
;;; 包管理
;;; -----------------------------------------------------------------------------

(require 'package)
(setq package-archives
      '(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ;; TUNA 的 MELPA 索引偶尔会先于归档文件同步，导致索引中的版本
        ;; 实际无法下载；LSP/DAP 依赖更新快，直接使用官方 MELPA。
        ("melpa"  . "https://melpa.org/packages/")))
(unless package--initialized
  (package-initialize))

;; 手动刷新：需要更新包索引时运行 M-x my/package-refresh-contents-when-stale。
;; 不在启动阶段自动联网，避免网络不可用时图形界面看起来卡住。
(defun my/package-archive-stale-p (&optional days)
  "Return t if package archive cache is older than DAYS (default 1)."
  (let* ((delta (or days 1))
         (file (expand-file-name "archives/melpa/archive-contents"
                                 package-user-dir))
         (age (and (file-exists-p file)
                   (/ (float-time (time-subtract (current-time)
                                                 (nth 5 (file-attributes file))))
                      86400))))
    (or (not age) (> age delta))))

(defun my/package-refresh-contents-when-stale ()
  "Refresh package archives after startup when the cache is stale."
  (when (my/package-archive-stale-p 1)
    (message "Refreshing stale package archives...")
    (package-refresh-contents)))

(unless (package-installed-p 'use-package)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; 避免 Custom 自动把内容写回 init.el。
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; 顶层依赖清单同时用于重建环境和保护 `package-autoremove'。
(defconst my/package-selected-packages
  '(cape cmake-mode consult consult-lsp corfu csharp-mode dap-mode dashboard doom-modeline
    doom-themes eat embark embark-consult
    eglot-java exec-path-from-shell grip-mode kind-icon leetcode magit marginalia markdown-mode
    lsp-mode lsp-treemacs lsp-ui markdown-preview-mode markdown-toc nerd-icons
    nerd-icons-completion nerd-icons-corfu nerd-icons-dired orderless
    org-appear org-modern org-roam org-super-agenda pandoc-mode toc-org
    transient treemacs use-package valign vertico which-key yasnippet)
  "Packages intentionally installed by this configuration.")
(setq package-selected-packages (copy-sequence my/package-selected-packages))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(require 'init-appearance)
(require 'init-icons)
(require 'init-modeline)
(require 'init-navigation)

;;; -----------------------------------------------------------------------------
;;; macOS：让图形版 Emacs 继承 shell 环境变量
;;; Java 重点：PATH / JAVA_HOME / JDK_HOME / MAVEN_HOME / GRADLE_HOME
;;; -----------------------------------------------------------------------------

(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x))
  :config
  (dolist (var '("PATH" "MANPATH"
                 "JAVA_HOME" "JDK_HOME" "MAVEN_HOME" "GRADLE_HOME" "GRAALVM_HOME"
                 "LIBRARY_PATH" "CPATH" "C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
                 "OPENAI_API_KEY" "ANTHROPIC_API_KEY"))
    (add-to-list 'exec-path-from-shell-variables var))
  (exec-path-from-shell-initialize))

(require 'subr-x)
(require 'cl-lib)

(defun my/macos-use-java-21-when-available ()
  "On macOS, set JAVA_HOME to Java 21 via /usr/libexec/java_home when unset."
  (when (and (eq system-type 'darwin)
             (not (getenv "JAVA_HOME"))
             (file-executable-p "/usr/libexec/java_home"))
    (let ((home (string-trim
                 (shell-command-to-string "/usr/libexec/java_home -v 21 2>/dev/null"))))
      (when (and (not (string-empty-p home))
                 (file-directory-p home))
        (setenv "JAVA_HOME" home)
        (add-to-list 'exec-path (expand-file-name "bin" home))))))

(my/macos-use-java-21-when-available)

;;; -----------------------------------------------------------------------------
;;; TAB：缩进 / 补全 / Snippet
;;; -----------------------------------------------------------------------------

(setq tab-always-indent t)

(declare-function yas-active-snippets "yasnippet")
(declare-function yas-next-field-or-maybe-expand "yasnippet")
(declare-function yas-maybe-expand-abbrev-key-filter "yasnippet" (command))
(declare-function yas-expand "yasnippet")
(declare-function corfu-complete "corfu")

(defun my/tab-dwim ()
  "Accept completion, expand a snippet, or indent at a logical tab stop.

When Corfu is visible, accept its selected candidate like a modern IDE.  In an
active Yasnippet, move to the next field; otherwise try snippet expansion.  C#
buffers insert spaces up to the next logical indentation stop; other modes
retain their normal syntax-aware indentation."
  (interactive)
  (cond
   ((and (bound-and-true-p completion-in-region-mode)
         (fboundp 'corfu-complete))
    (call-interactively #'corfu-complete))
   ((and (bound-and-true-p yas-minor-mode)
         (fboundp 'yas-active-snippets)
         (yas-active-snippets))
    (call-interactively #'yas-next-field-or-maybe-expand))
   ((and (bound-and-true-p yas-minor-mode)
         (fboundp 'yas-maybe-expand-abbrev-key-filter)
         (yas-maybe-expand-abbrev-key-filter #'yas-expand))
    (call-interactively #'yas-expand))
   (t
    (if (derived-mode-p 'csharp-mode 'csharp-ts-mode)
        (let* ((width
                (max 1
                     (if (boundp 'my/csharp-indent-width)
                         (symbol-value 'my/csharp-indent-width)
                       4)))
               (remainder (% (current-column) width))
               (spaces (if (zerop remainder)
                           width
                         (- width remainder))))
          (insert (make-string spaces ?\s)))
      (indent-for-tab-command)))))

(use-package corfu
  :hook ((prog-mode . corfu-mode)
         (text-mode . corfu-mode))
  :bind (:map corfu-map
              ("TAB" . corfu-complete)
              ("<tab>" . corfu-complete))
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  (corfu-auto-delay 0.25)
  (corfu-auto-prefix 2)
  (corfu-preselect 'first)
  (corfu-preview-current nil)
  (corfu-count 12)
  (corfu-min-width 30)
  (corfu-max-width 90)
  :config
  ;; Show documentation beside the candidate list only while completion is
  ;; active.  The modest delay avoids a resolve request for every keystroke.
  (require 'corfu-popupinfo)
  (setq corfu-popupinfo-delay '(0.65 . 0.25)
        corfu-popupinfo-max-width 80
        corfu-popupinfo-max-height 16)
  (corfu-popupinfo-mode 1))

(use-package cape
  :after corfu
  :init
  ;; 只在 eglot 的 capf 之后追加文件路径补全，避免干扰 LSP
  (defun my/setup-cape-backends ()
    (add-to-list 'completion-at-point-functions #'cape-file t))
  (add-hook 'prog-mode-hook #'my/setup-cape-backends))

(use-package yasnippet
  :hook ((prog-mode . yas-minor-mode)
         (text-mode . yas-minor-mode)))

(use-package magit
  :bind (("C-x g" . magit-status)))

;;; -----------------------------------------------------------------------------
;;; Markdown：稳定优先
;;; -----------------------------------------------------------------------------

(use-package markdown-mode
  :mode (("\\.md\\'"  . gfm-mode)
         ("\\.mkd\\'" . gfm-mode))
  :init
  (setq markdown-command "pandoc"))

(use-package grip-mode
  :after markdown-mode
  :bind (:map markdown-mode-command-map
              ("p" . grip-mode))
  :custom
  (grip-update-interval 1))

(use-package markdown-toc
  :after markdown-mode)

(use-package pandoc-mode
  :hook ((markdown-mode . pandoc-mode)
         (gfm-mode . pandoc-mode)))

;;; Markdown 实时预览：本地 WebSocket 服务器 + 浏览器，支持 KaTeX 数学公式
(use-package markdown-preview-mode
  :after markdown-mode
  :commands markdown-preview-mode
  :config
  ;; 使用 KaTeX 渲染 LaTeX 公式（比 MathJax 更快更轻量）
  (setq markdown-preview-stylesheets
        '("https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"))
  (setq markdown-preview-javascript
        '("https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"
          "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"))
  (setq markdown-preview-script-onupdate
        "renderMathInElement(document.body, {delimiters: [{left: '$$', right: '$$', display: true}, {left: '$', right: '$', display: false}, {left: '\\\\[', right: '\\\\]', display: true}, {left: '\\\\(', right: '\\\\)', display: false}]});")
  ;; 预览窗口自动跟随滚动（可选）
  (setq markdown-preview-auto-open 'http))

(with-eval-after-load 'markdown-mode
  (define-key markdown-mode-command-map
              (kbd "P") #'markdown-preview-mode))

(use-package cmake-mode
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))

(with-eval-after-load 'markdown-mode
  (define-key markdown-mode-command-map
              (kbd "t") #'markdown-toc-generate-toc))

;;; -----------------------------------------------------------------------------
;;; Tree-sitter：兼容版
;;; M-x my/treesit-install-grammars 可安装缺失 grammar
;;; -----------------------------------------------------------------------------

(defun my/treesit-ok-p (lang)
  "Return non-nil when tree-sitter and LANG grammar are both available."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (fboundp 'treesit-language-available-p)
       (treesit-language-available-p lang)))

(when (and (fboundp 'treesit-available-p)
           (treesit-available-p))

  (setq treesit-language-source-alist
        '((bash       "https://github.com/tree-sitter/tree-sitter-bash")
          (c          "https://github.com/tree-sitter/tree-sitter-c")
          (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")
          (css        "https://github.com/tree-sitter/tree-sitter-css")
          (go         "https://github.com/tree-sitter/tree-sitter-go")
          (html       "https://github.com/tree-sitter/tree-sitter-html")
          (java       "https://github.com/tree-sitter/tree-sitter-java")
          (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
          (json       "https://github.com/tree-sitter/tree-sitter-json")
          (python     "https://github.com/tree-sitter/tree-sitter-python")
          (rust       "https://github.com/tree-sitter/tree-sitter-rust")
          (toml       "https://github.com/tree-sitter/tree-sitter-toml")
          (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
          (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
          (yaml       "https://github.com/ikatyang/tree-sitter-yaml")
          ;; v0.23.2 起 grammar 生成了 ABI 15，而 Emacs 30 仅支持 ABI 13/14。
          ;; 固定到经 parser.c 验证仍为 ABI 14 的正式标签。
          (c-sharp    "https://github.com/tree-sitter/tree-sitter-c-sharp" "v0.23.1")))

  (defun my/treesit-install-grammars ()
    "Install missing tree-sitter grammars."
    (interactive)
    (dolist (lang '(bash c cpp css go html java javascript json python rust toml tsx typescript yaml c-sharp))
      (unless (my/treesit-ok-p lang)
        (message "Installing tree-sitter grammar for %s..." lang)
        (condition-case err
            (treesit-install-language-grammar lang)
          (error
           (message "Failed to install %s: %s"
                    lang (error-message-string err)))))))

  (defun my/treesit-doctor ()
    "Show tree-sitter status."
    (interactive)
    (message
     "treesit=%s | java=%S | c=%S | cpp=%S | csharp=%S | python=%S | js=%S"
     (if (and (fboundp 'treesit-available-p) (treesit-available-p)) "ok" "missing")
     (and (fboundp 'treesit-language-available-p) (treesit-language-available-p 'java t))
     (and (fboundp 'treesit-language-available-p) (treesit-language-available-p 'c t))
     (and (fboundp 'treesit-language-available-p) (treesit-language-available-p 'cpp t))
     (and (fboundp 'treesit-language-available-p) (treesit-language-available-p 'c-sharp t))
     (and (fboundp 'treesit-language-available-p) (treesit-language-available-p 'python t))
     (and (fboundp 'treesit-language-available-p) (treesit-language-available-p 'javascript t))))

  (dolist (spec '((c-mode      c-ts-mode        c)
                  (csharp-mode csharp-ts-mode   c-sharp)
                  (c++-mode    c++-ts-mode      cpp)
                  (sh-mode     bash-ts-mode     bash)
                  (css-mode    css-ts-mode      css)
                  (js-mode     js-ts-mode       javascript)
                  (json-mode   json-ts-mode     json)
                  (python-mode python-ts-mode   python)
                  (go-mode     go-ts-mode       go)
                  (java-mode   java-ts-mode     java)
                  (rust-mode   rust-ts-mode     rust)
                  (yaml-mode   yaml-ts-mode     yaml)))
    (pcase-let ((`(,from ,to ,lang) spec))
      (when (and (fboundp to)
                 (my/treesit-ok-p lang))
        (add-to-list 'major-mode-remap-alist (cons from to)))))

  (when (and (fboundp 'typescript-ts-mode)
             (my/treesit-ok-p 'typescript))
    (add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode)))

  (when (and (fboundp 'tsx-ts-mode)
             (my/treesit-ok-p 'tsx))
    (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode)))

  (when (and (fboundp 'toml-ts-mode)
             (my/treesit-ok-p 'toml))
    (add-to-list 'auto-mode-alist '("\\.toml\\'" . toml-ts-mode))))

;;; -----------------------------------------------------------------------------
;;; Eglot：统一 LSP 客户端
;;; -----------------------------------------------------------------------------

(use-package eglot
  :custom
  (eglot-autoshutdown t)
  ;; 保留有限日志，便于诊断 JDT LS/clangd 协议问题。
  (eglot-events-buffer-size 200000)
  :bind (("C-c l a" . eglot-code-actions)
         ("C-c l r" . eglot-rename)
         ("C-c l f" . eglot-format-buffer)
         ("C-c l d" . xref-find-definitions)
         ("C-c l D" . xref-find-references)
         ("C-c l q" . eglot-shutdown)
         ("C-c l R" . eglot-reconnect)
         ("C-c l t" . my/toggle-eglot-buffer)))

(defun my/leetcode-p ()
  "判断当前文件是否是 LeetCode 题解文件。
支持路径中包含 leetcode/lc，或文件名纯数字如 123.cpp"
  (when buffer-file-name
    (let ((path (downcase buffer-file-name))
          (name (file-name-nondirectory buffer-file-name)))
      (or (string-match-p "leetcode" path)
          (string-match-p "/lc/" path)
          (string-match-p "^\\(lc\\|leetcode\\)" (file-name-base buffer-file-name))
          (string-match-p "^[0-9]+\\.cpp$" name)
          (string-match-p "^[0-9]+\\.c$"   name)))))

(defun my/eglot-maybe-ensure ()
  "启动 Eglot，但 LeetCode 单文件不启动，避免满屏报错。"
  (unless (my/leetcode-p)
    (eglot-ensure)))

(defun my/toggle-eglot-buffer ()
  "切换当前 buffer 的 Eglot 连接。"
  (interactive)
  (if (and (fboundp 'eglot-managed-p) (eglot-managed-p))
      (progn (eglot-shutdown) (message "Eglot 已关闭"))
    (eglot-ensure) (message "Eglot 已启动")))

(with-eval-after-load 'eglot
  ;; C/C++: clangd with background index and clang-tidy
  ;; 单独为每个 mode 注册，兼容所有 Eglot 版本
  (dolist (mode '(c-mode c-ts-mode c++-mode c++-ts-mode))
    (add-to-list 'eglot-server-programs
                 `(,mode . ("clangd"
                            "--background-index"
                            "--clang-tidy"
                            "--header-insertion=iwyu"
                            "--completion-style=bundled"
                            "--fallback-style={BasedOnStyle: LLVM, IndentWidth: 4, ContinuationIndentWidth: 4, TabWidth: 4, UseTab: Never, ColumnLimit: 100}")))))

(defun my/eglot-format-buffer-on-save ()
  "Format current buffer on save when Eglot manages it."
  (when (and (fboundp 'eglot-managed-p)
             (eglot-managed-p))
    (condition-case err
        (eglot-format-buffer)
      (error
       (message "Eglot format skipped: %s" (error-message-string err))))))

(defun my/require-executable (program)
  "Return PROGRAM's executable path or signal a helpful user error."
  (or (executable-find program)
      (user-error "Required executable not found: %s" program)))

(defun my/project-find-cmake-root (dir)
  "Treat the nearest CMakeLists.txt above DIR as a project root."
  (when-let ((root (locate-dominating-file dir "CMakeLists.txt")))
    (cons 'transient (file-name-as-directory (expand-file-name root)))))

;; Keep VC projects as the first choice; use CMake for projects without Git.
(add-hook 'project-find-functions #'my/project-find-cmake-root t)

(defun my/project-detect-build-command (root)
  "Detect build command for project at ROOT.
Supports CMake, Make, and Ninja."
  (let ((build-dir (expand-file-name "build/" root)))
    (cond
     ((or (file-exists-p (expand-file-name "CMakeCache.txt" build-dir))
          (file-exists-p (expand-file-name "build.ninja" build-dir))
          (file-exists-p (expand-file-name "Makefile" build-dir)))
      "cmake --build build")
     ((file-exists-p (expand-file-name "build.ninja" root))
      "ninja")
     ((or (file-exists-p (expand-file-name "Makefile" root))
          (file-exists-p (expand-file-name "makefile" root)))
      "make")
     ((file-exists-p (expand-file-name "CMakeLists.txt" root))
      (concat "cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
              " && cmake --build build"))
     (t nil))))

(defun my/cmake-configure-project ()
  "Configure current CMake project: generate build/ + compile_commands.json.
Creates a symlink compile_commands.json → build/compile_commands.json
so that clangd can find it automatically."
  (interactive)
  (let* ((root (my/project-root-or-current))
         (cmake-file (expand-file-name "CMakeLists.txt" root)))
    (unless (file-exists-p cmake-file)
      (user-error "No CMakeLists.txt found in %s" root))
    (my/require-executable "cmake")
    (let ((default-directory root))
      (let ((buffer
             (compile
              "cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON")))
        ;; `compile' is asynchronous, so create the link only after success.
        (with-current-buffer buffer
          (add-hook
           'compilation-finish-functions
           (lambda (_buffer status)
             (when (string-prefix-p "finished" status)
               (let ((json (expand-file-name "compile_commands.json" root))
                     (json-in-build
                      (expand-file-name "build/compile_commands.json" root)))
                 (when (and (file-exists-p json-in-build)
                            (not (file-exists-p json))
                            (not (file-symlink-p json)))
                   (make-symbolic-link "build/compile_commands.json" json)
                   (message
                    "Created symlink: compile_commands.json -> build/compile_commands.json")))))
           nil t))))))

(defun my/cpp-project-build ()
  "Build current C/C++ project using detected build system."
  (interactive)
  (let* ((root (my/project-root-or-current))
         (cmd (my/project-detect-build-command root)))
    (unless cmd
      (user-error "No build system found: missing Makefile, build.ninja or CMakeLists.txt"))
    (my/require-executable (car (split-string-and-unquote cmd)))
    (let ((default-directory root))
      (compile cmd))))

(defun my/cpp-project-run ()
  "Run compiled executable in current project.
Searches build/ directory or project root."
  (interactive)
  (let* ((root (my/project-root-or-current))
         (default-directory root)
         (candidates
          (append
           (file-expand-wildcards "build/*" t)
           (file-expand-wildcards "*.out" t)
           (file-expand-wildcards "a.out" t)))
         (executables
          (delete-dups
           (cl-remove-if-not (lambda (f)
                               (and (file-regular-p f)
                                    (file-executable-p f)))
                             candidates)))
         (exe (cond
               ((null executables) nil)
               ((= (length executables) 1) (car executables))
               (t (completing-read "Run executable: " executables nil t)))))
    (unless (and exe (not (string-empty-p exe)))
      (user-error "No executable found. Build the project first with C-c b"))
    (compile (shell-quote-argument exe))))

;;; -----------------------------------------------------------------------------
;;; Java / Maven / Gradle
;;; -----------------------------------------------------------------------------

(defun my/java-mode-setup ()
  "Java editing setup."
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)
  (setq-local c-basic-offset 4)
  (when (boundp 'java-ts-mode-indent-offset)
    (setq-local java-ts-mode-indent-offset 4))
  (subword-mode 1)
  ;; Eglot 默认用 Flymake；避免 flycheck 和 flymake 双诊断。
  (when (fboundp 'flycheck-mode)
    (flycheck-mode -1))
  (flymake-mode 1)
  ;; 不想保存自动格式化时，注释下一行。
  (add-hook 'before-save-hook #'my/eglot-format-buffer-on-save nil t))

(defun my/java-eglot-setup ()
  "Set up Java editing and start Eglot through eglot-java."
  (my/java-mode-setup)
  ;; `eglot-java-mode' already calls `eglot-ensure'.
  (eglot-java-mode 1))

(use-package eglot-java
  :commands eglot-java-mode
  :hook ((java-mode . my/java-eglot-setup)
         (java-ts-mode . my/java-eglot-setup))
  :custom
  (eglot-java-eglot-server-programs-manual-updates t)
  (eglot-java-server-install-dir
   (expand-file-name "share/eclipse.jdt.ls" user-emacs-directory))
  ;; 用 JAVA_HOME 启动 JDT Language Server；当前推荐指向 JDK 21+。
  (eglot-java-java-home (getenv "JAVA_HOME"))
  ;; 大项目可把 -Xmx2G 改成 -Xmx4G。
  (eglot-java-eclipse-jdt-args
   '("-Xms256m"
     "-Xmx2G"
     "--add-modules=ALL-SYSTEM"
     "--add-opens" "java.base/java.util=ALL-UNNAMED"
     "--add-opens" "java.base/java.lang=ALL-UNNAMED"))
  :bind (:map eglot-java-mode-map
              ("C-c j n" . eglot-java-file-new)
              ("C-c j N" . eglot-java-project-new)
              ("C-c j r" . eglot-java-run-main)
              ("C-c j t" . eglot-java-run-test)
              ("C-c j b" . eglot-java-project-build-task)
              ("C-c j R" . eglot-java-project-build-refresh)
              ("C-c j u" . eglot-java-upgrade-lsp-server)))

(defun my/project-root-or-current ()
  "Return project root or `default-directory'."
  (if-let ((project (project-current nil)))
      (project-root project)
    default-directory))

(defun my/java--maven-wrapper-p (root)
  (file-exists-p (expand-file-name (if (eq system-type 'windows-nt) "mvnw.cmd" "mvnw") root)))

(defun my/java--gradle-wrapper-p (root)
  (file-exists-p (expand-file-name (if (eq system-type 'windows-nt) "gradlew.bat" "gradlew") root)))

(defun my/java--build-tool-command (root kind)
  "Return Java project command for ROOT and KIND.
KIND can be `test' or `build'."
  (let ((win (eq system-type 'windows-nt)))
    (cond
     ((my/java--maven-wrapper-p root)
      (if (eq kind 'test)
          (if win "mvnw.cmd test" "./mvnw test")
        (if win "mvnw.cmd clean package" "./mvnw clean package")))
     ((file-exists-p (expand-file-name "pom.xml" root))
      (if (eq kind 'test) "mvn test" "mvn clean package"))
     ((my/java--gradle-wrapper-p root)
      (if (eq kind 'test)
          (if win "gradlew.bat test" "./gradlew test")
        (if win "gradlew.bat build" "./gradlew build")))
     ((or (file-exists-p (expand-file-name "build.gradle" root))
          (file-exists-p (expand-file-name "build.gradle.kts" root)))
      (if (eq kind 'test) "gradle test" "gradle build"))
     (t
      nil))))

(defun my/java-project-test ()
  "Run Maven/Gradle tests for current Java project."
  (interactive)
  (let* ((root (my/project-root-or-current))
         (cmd (my/java--build-tool-command root 'test)))
    (unless cmd
      (user-error "No Maven/Gradle project found: missing pom.xml or build.gradle"))
    (let ((default-directory root))
      (compile cmd))))

(defun my/java-project-build ()
  "Run Maven/Gradle build for current Java project."
  (interactive)
  (let* ((root (my/project-root-or-current))
         (cmd (my/java--build-tool-command root 'build)))
    (unless cmd
      (user-error "No Maven/Gradle project found: missing pom.xml or build.gradle"))
    (let ((default-directory root))
      (compile cmd))))

(with-eval-after-load 'eglot-java
  ;; eglot-java 只自动覆盖 java-mode；java-ts-mode 需要一并注册。
  (setq eglot-server-programs
        (cl-remove-if
         (lambda (entry)
           (let ((modes (car-safe entry)))
             (or (eq modes 'java-mode)
                 (eq modes 'java-ts-mode)
                 (and (listp modes)
                      (or (memq 'java-mode modes)
                          (memq 'java-ts-mode modes))))))
         eglot-server-programs))
  (add-to-list 'eglot-server-programs
               '((java-mode java-ts-mode) . eglot-java--eclipse-contact))
  ;; JDT LS 1.58 may send RelativePattern objects for file watchers, while
  ;; Emacs 30 Eglot expects plain glob strings.
  (cl-defmethod eglot-register-capability :around
    ((server eglot-java-eclipse-jdt)
     (method (eql workspace/didChangeWatchedFiles))
     id &rest params)
    (let ((watchers (plist-get params :watchers)))
      (if watchers
          (apply
           #'cl-call-next-method
           server method id
           (plist-put
            (copy-sequence params)
            :watchers
            (vconcat
             (mapcar
              (lambda (watcher)
                (let* ((copy (copy-sequence watcher))
                       (glob (plist-get copy :globPattern)))
                  (when (and (listp glob)
                             (plist-member glob :pattern))
                    (setq copy (plist-put copy :globPattern
                                          (plist-get glob :pattern))))
                  copy))
              (append watchers nil)))))
        (cl-call-next-method))))
  (define-key eglot-java-mode-map (kbd "C-c j p") #'my/java-project-build)
  (define-key eglot-java-mode-map (kbd "C-c j T") #'my/java-project-test))

;;; -----------------------------------------------------------------------------
;;; C/C++
;;; -----------------------------------------------------------------------------

;; Better GDB UI: show source + locals + stack + breakpoints side by side
(setq gdb-many-windows t)
(setq gdb-show-main t)

(defun compile-and-run-c++ ()
  "Compile and run current C/C++ file."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a C/C++ source file"))
  (save-buffer)
  (let* ((file buffer-file-name)
         (c-source-p (string-equal (downcase (or (file-name-extension file) ""))
                                   "c"))
         (compiler (if c-source-p "cc" "c++"))
         (standard (if c-source-p "-std=c17" "-std=c++17"))
         (exe (concat (make-temp-name
                       (expand-file-name "emacs-c-run-" temporary-file-directory))
                      (if (eq system-type 'windows-nt) ".exe" "")))
         (cmd (format "%s %s -O2 -Wall %s -o %s && %s"
                      compiler
                      standard
                      (shell-quote-argument file)
                      (shell-quote-argument exe)
                      (shell-quote-argument exe))))
    (my/require-executable compiler)
    (let ((buffer (compile cmd)))
      ;; Delete only the unique temporary executable, on success or failure.
      (with-current-buffer buffer
        (add-hook 'compilation-finish-functions
                  (lambda (_buffer _status)
                    (when (file-exists-p exe)
                      (delete-file exe)))
                  nil t)))))

(defun my/cpp-debug ()
  "Start GDB for current C/C++ program.
Automatically finds executable: single-file exe first, then project build output."
  (interactive)
  (my/require-executable "gdb")
  (let* ((file (buffer-file-name))
         (default-directory (my/project-root-or-current))
         (candidates '()))
    ;; 1. Try single-file executable (same name as source)
    (when file
      (let ((single-exe (file-name-sans-extension file)))
        (when (and (file-regular-p single-exe)
                   (file-executable-p single-exe))
          (push single-exe candidates))))
    ;; 2. Try a.out in current directory
    (when (and (file-regular-p "a.out")
               (file-executable-p "a.out"))
      (push (expand-file-name "a.out") candidates))
    ;; 3. Try executables in build/
    (setq candidates
          (append candidates
                  (cl-remove-if-not
                   (lambda (f) (and (file-regular-p f)
                                    (file-executable-p f)))
                   (file-expand-wildcards "build/*" t))))
    ;; 4. Deduplicate and pick
    (setq candidates (delete-dups candidates))
    (let ((exe (cond ((null candidates)
                      nil)
                     ((= (length candidates) 1)
                      (car candidates))
                     (t
                      (completing-read "Debug executable: " candidates nil t)))))
      (unless (and exe (not (string-empty-p exe)))
        (user-error "No executable found. Compile first with C-c r (single file) or C-c b (project)"))
      (gdb (concat "gdb -i=mi " (shell-quote-argument exe))))))

(defun my/c-ts-indent-style ()
  "Return K&R indentation with fixed-width continued arguments.
Unlike the stock K&R rules, continuation lines are indented one level
instead of being aligned all the way to the opening parenthesis."
  (let* ((language (if (eq major-mode 'c++-ts-mode) 'cpp 'c))
         (base-rules
          (alist-get 'k&r (c-ts-mode--indent-styles language))))
    (append
     '(((node-is ")") parent 1)
       ((parent-is "argument_list") parent-bol c-ts-mode-indent-offset)
       ((parent-is "parameter_list") parent-bol c-ts-mode-indent-offset))
     base-rules)))

(defcustom my/cpp-format-on-save t
  "Control Eglot formatting when saving C/C++ buffers.
The value `project' enables it only when a .clang-format or
_clang-format file exists above the current file.  A non-nil value
always enables it, while nil disables it."
  :type '(choice (const :tag "Projects with clang-format" project)
                 (const :tag "Always" t)
                 (const :tag "Never" nil))
  :group 'tools)

(defun my/cpp-format-config-p ()
  "Return non-nil when the current C/C++ project has a format file."
  (let ((dir (or (and buffer-file-name
                      (file-name-directory buffer-file-name))
                 default-directory)))
    (or (locate-dominating-file dir ".clang-format")
        (locate-dominating-file dir "_clang-format"))))

(defun my/cpp-format-on-save-enabled-p ()
  "Return non-nil when this buffer should format before saving."
  (or (eq my/cpp-format-on-save t)
      (and (eq my/cpp-format-on-save 'project)
           (my/cpp-format-config-p))))

(defun my/cpp-format-buffer ()
  "Format the current C/C++ buffer using project or global defaults."
  (interactive)
  (eglot-format-buffer))

(defun my/cpp-toggle-format-on-save ()
  "Toggle Eglot formatting on save in the current C/C++ buffer."
  (interactive)
  (setq-local my/cpp-format-on-save
              (if (my/cpp-format-on-save-enabled-p) nil t))
  (if (my/cpp-format-on-save-enabled-p)
      (add-hook 'before-save-hook #'my/eglot-format-buffer-on-save nil t)
    (remove-hook 'before-save-hook #'my/eglot-format-buffer-on-save t))
  (message "C/C++ format on save %s"
           (if (my/cpp-format-on-save-enabled-p) "enabled" "disabled")))

(defun my/cpp-mode-setup ()
  "My C/C++ editing setup."
  (local-set-key (kbd "C-c r") #'compile-and-run-c++)
  (local-set-key (kbd "C-c d") #'my/cpp-debug)
  (local-set-key (kbd "C-c o") #'ff-find-other-file)
  (local-set-key (kbd "C-c b") #'my/cpp-project-build)
  (local-set-key (kbd "C-c B") #'my/cmake-configure-project)
  (local-set-key (kbd "C-c R") #'my/cpp-project-run)
  (local-set-key (kbd "C-c l f") #'my/cpp-format-buffer)
  (local-set-key (kbd "C-c l s") #'my/cpp-toggle-format-on-save)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)
  (setq-local c-basic-offset 4)
  ;; Use four-space K&R indentation without deep parenthesis alignment.
  (if (memq major-mode '(c-ts-mode c++-ts-mode))
      (progn
        (setq-local c-ts-mode-indent-offset 4)
        (c-ts-mode-set-style #'my/c-ts-indent-style))
    (c-set-style "stroustrup"))
  (when (fboundp 'flycheck-mode)
    (flycheck-mode -1))
  (flymake-mode 1)
  ;; Format on save by default; `C-c l s' toggles it for this buffer.
  (if (my/cpp-format-on-save-enabled-p)
      (add-hook 'before-save-hook #'my/eglot-format-buffer-on-save nil t)
    (remove-hook 'before-save-hook #'my/eglot-format-buffer-on-save t)))

(add-hook 'c++-mode-hook #'my/cpp-mode-setup)
(add-hook 'c++-ts-mode-hook #'my/cpp-mode-setup)
(add-hook 'c-mode-hook #'my/cpp-mode-setup)
(add-hook 'c-ts-mode-hook #'my/cpp-mode-setup)

;; Ensure Eglot starts automatically for C/C++
;; LeetCode 文件自动跳过，避免单文件满屏报错
(add-hook 'c-mode-hook #'my/eglot-maybe-ensure)
(add-hook 'c++-mode-hook #'my/eglot-maybe-ensure)
(add-hook 'c-ts-mode-hook #'my/eglot-maybe-ensure)
(add-hook 'c++-ts-mode-hook #'my/eglot-maybe-ensure)

;;; -----------------------------------------------------------------------------
;;; C# / Unity / .NET / DAP
;;; C# 使用 lsp-mode；其他语言仍可继续使用上面的 Eglot 配置。
;;; -----------------------------------------------------------------------------

(require 'init-unity)
(require 'init-csharp)
(require 'init-dotnet)
(require 'init-debug)

;;; -----------------------------------------------------------------------------
;;; Ghostty / Codex 外部模块：保留你原来的加载方式
;;; -----------------------------------------------------------------------------

;;; ---------------------------------------------------------------------------
;;; Org: 笔记 + 任务 + 知识库
;;; ---------------------------------------------------------------------------
(require 'init-org)
(condition-case err
    (require 'init-dashboard)
  (error
   ;; 启动页属于增强功能；包损坏或离线安装失败时仍应进入可用的 Emacs。
   (setq initial-buffer-choice nil)
   (display-warning
    'init-dashboard
    (format "Dashboard 已停用：%s" (error-message-string err))
    :warning)))

(let ((ai-workflow-file
       (expand-file-name "~/.config/ai-workflow/emacs/ai-ghostty-codex-workflow.el")))
  (when (file-readable-p ai-workflow-file)
    (let ((inhibit-message t))
      ;; 环境变量已由上面的单次 initialize 批量导入。旧模块加载时会再
      ;; 逐个查询两个 API key；在这次加载期间直接返回现有值，避免两个
      ;; 额外的交互式 login shell。
      (if (fboundp 'exec-path-from-shell-copy-env)
          (cl-letf (((symbol-function 'exec-path-from-shell-copy-env)
                     (lambda (name) (getenv name))))
            (load ai-workflow-file nil t))
        (load ai-workflow-file nil t)))))

(provide 'init)
;;; init.el ends here
