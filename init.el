;;; init.el --- stable Emacs config with Java/Eglot support -*- lexical-binding: t; -*-

;; 这份配置是在你现有 init.el 基础上整理而来：
;; - 保留：基础 UI、macOS 键位、Markdown、Tree-sitter、C/C++、C#、Ghostty/Codex 外部模块
;; - 清理：重复的 package 初始化、自定义区写入 init.el、未防护的 flycheck/clang-format 调用
;; - 新增：Vertico/Consult/Corfu 补全体系、Java Tree-sitter、eglot-java、Maven/Gradle 快捷命令

;;; -----------------------------------------------------------------------------
;;; 基础界面
;;; -----------------------------------------------------------------------------

(setenv "http_proxy" "http://127.0.0.1:10808")
(setenv "https_proxy" "http://127.0.0.1:10808")

(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq ring-bell-function #'ignore)

(when (fboundp 'tool-bar-mode)   (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode)   (menu-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(add-to-list 'default-frame-alist '(fullscreen . maximized))

(global-display-line-numbers-mode 1)
(column-number-mode 1)
(global-hl-line-mode 1)
(show-paren-mode 1)
(setq show-paren-delay 0)

(setq mode-line-format
      '(" " mode-line-modified
        " " mode-line-buffer-identification
        " " mode-line-position
        " " mode-line-modes))

;;; -----------------------------------------------------------------------------
;;; 编辑行为
;;; -----------------------------------------------------------------------------

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default c-basic-offset 4)

(electric-pair-mode 1)
(delete-selection-mode 1)
(save-place-mode 1)
(recentf-mode 1)

(setq make-backup-files nil)
(setq auto-save-default nil)
(setq create-lockfiles nil)

(global-set-key (kbd "C-c c") #'compile)
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
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; 避免 Custom 自动把内容写回 init.el。
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(use-package chocolate-theme
  :config
  (load-theme 'chocolate t))

;;; -----------------------------------------------------------------------------
;;; macOS：让图形版 Emacs 继承 shell 环境变量
;;; Java 重点：PATH / JAVA_HOME / JDK_HOME / MAVEN_HOME / GRADLE_HOME
;;; -----------------------------------------------------------------------------

(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x))
  :config
  (dolist (var '("PATH" "MANPATH"
                 "JAVA_HOME" "JDK_HOME" "MAVEN_HOME" "GRADLE_HOME" "GRAALVM_HOME"
                 "LIBRARY_PATH" "CPATH" "C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"))
    (add-to-list 'exec-path-from-shell-variables var))
  (exec-path-from-shell-initialize))

(require 'subr-x)

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
;;; 通用补全 / 搜索 / 项目体验
;;; -----------------------------------------------------------------------------

(use-package which-key
  :config
  (which-key-mode 1))

(use-package vertico
  :init
  (vertico-mode 1))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :after vertico
  :init
  (marginalia-mode 1))

(use-package consult
  :bind (("C-s"     . consult-line)
         ("C-c b"   . consult-buffer)
         ("C-c g"   . consult-grep)
         ("C-c r"   . consult-ripgrep)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-g e"   . consult-flymake)))

(use-package corfu
  :init
  (global-corfu-mode 1)
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 1)
  (corfu-preview-current nil))

(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file))

(use-package yasnippet
  :config
  (yas-global-mode 1))

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
          (c-sharp    "https://github.com/tree-sitter/tree-sitter-c-sharp")))

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
  (eglot-events-buffer-size 0)
  :bind (("C-c l a" . eglot-code-actions)
         ("C-c l r" . eglot-rename)
         ("C-c l f" . eglot-format-buffer)
         ("C-c l d" . xref-find-definitions)
         ("C-c l D" . xref-find-references)
         ("C-c l q" . eglot-shutdown)
         ("C-c l R" . eglot-reconnect)))

(defun my/eglot-format-buffer-on-save ()
  "Format current buffer on save when Eglot manages it."
  (when (and (fboundp 'eglot-managed-p)
             (eglot-managed-p))
    (ignore-errors
      (eglot-format-buffer))))

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

(use-package eglot-java
  :after eglot
  :hook ((java-mode . my/java-mode-setup)
         (java-ts-mode . my/java-mode-setup)
         (java-mode . eglot-java-mode)
         (java-ts-mode . eglot-java-mode))
  :custom
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
  (define-key eglot-java-mode-map (kbd "C-c j p") #'my/java-project-build)
  (define-key eglot-java-mode-map (kbd "C-c j T") #'my/java-project-test))

;;; -----------------------------------------------------------------------------
;;; C/C++
;;; -----------------------------------------------------------------------------

(defun compile-and-run-c++ ()
  "Compile and run current C/C++ file."
  (interactive)
  (save-buffer)
  (let* ((file (buffer-file-name))
         (base (file-name-sans-extension file))
         (exe  (if (eq system-type 'windows-nt)
                   (concat base ".exe")
                 base))
         (cmd  (if (eq system-type 'windows-nt)
                   (format "g++ -std=c++17 -O2 -Wall %s -o %s && %s"
                           (shell-quote-argument file)
                           (shell-quote-argument exe)
                           (shell-quote-argument exe))
                 (format "g++ -std=c++17 -O2 -Wall %s -o %s && %s; rm -f %s"
                         (shell-quote-argument file)
                         (shell-quote-argument exe)
                         (shell-quote-argument exe)
                         (shell-quote-argument exe)))))
    (compile cmd)))

(defun my/cpp-mode-setup ()
  "My C/C++ editing setup."
  (local-set-key (kbd "C-c r") #'compile-and-run-c++)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (when (fboundp 'flycheck-mode)
    (flycheck-mode -1))
  (flymake-mode 1)
  ;; 如果安装了 clang-format 包/命令，保存时自动格式化。
  (when (fboundp 'clang-format-buffer)
    (add-hook 'before-save-hook #'clang-format-buffer nil t)))

(add-hook 'c++-mode-hook #'my/cpp-mode-setup)
(add-hook 'c++-ts-mode-hook #'my/cpp-mode-setup)
(add-hook 'c-mode-hook #'my/cpp-mode-setup)
(add-hook 'c-ts-mode-hook #'my/cpp-mode-setup)

;;; -----------------------------------------------------------------------------
;;; C# / Unity
;;; 依赖：dotnet tool install -g csharp-ls
;;; -----------------------------------------------------------------------------

(use-package csharp-mode
  :mode "\\.cs\\'"
  :init
  (when (and (fboundp 'csharp-ts-mode)
             (my/treesit-ok-p 'c-sharp))
    (add-to-list 'major-mode-remap-alist '(csharp-mode . csharp-ts-mode))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(csharp-mode . ("csharp-ls")))
  (add-to-list 'eglot-server-programs '(csharp-ts-mode . ("csharp-ls"))))

(add-hook 'csharp-mode-hook #'eglot-ensure)
(add-hook 'csharp-ts-mode-hook #'eglot-ensure)

(defun my/csharp-mode-setup ()
  "C# / Unity editing setup."
  (setq-local c-basic-offset 4)
  (setq-local tab-width 4)
  (setq-local indent-tabs-mode nil)
  (when (fboundp 'flycheck-mode)
    (flycheck-mode -1))
  (flymake-mode 1))

(add-hook 'csharp-mode-hook #'my/csharp-mode-setup)
(add-hook 'csharp-ts-mode-hook #'my/csharp-mode-setup)

;;; -----------------------------------------------------------------------------
;;; Ghostty / Codex 外部模块：保留你原来的加载方式
;;; -----------------------------------------------------------------------------

(let ((ai-workflow-file "/Users/rytukim/.config/ai-workflow/emacs/ai-ghostty-codex-workflow.el"))
  (when (file-readable-p ai-workflow-file)
    (load ai-workflow-file nil t)))

(provide 'init)
;;; init.el ends here
