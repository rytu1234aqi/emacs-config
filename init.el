;;; init.el --- stable Emacs config

;; -----------------------------
;; 基础界面
;; -----------------------------
(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)

(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'menu-bar-mode)
  (menu-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

(add-to-list 'default-frame-alist '(fullscreen . maximized))

(global-display-line-numbers-mode t)
(column-number-mode t)
(global-hl-line-mode t)
(show-paren-mode t)
(setq show-paren-delay 0)

(setq mode-line-format
      '(" " mode-line-modified
        " " mode-line-buffer-identification
        " " mode-line-position))

(load-theme 'tango-dark t)

;; -----------------------------
;; 编辑行为
;; -----------------------------
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

(electric-pair-mode t)
(delete-selection-mode t)

(setq make-backup-files nil)
(setq auto-save-default nil)

;; -----------------------------
;; 快捷键
;; -----------------------------
(global-set-key (kbd "C-c c") #'compile)
(global-set-key (kbd "C-x C-b") #'ibuffer)

;; -----------------------------
;; 包管理
;; -----------------------------
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; -----------------------------
;; macOS：让 Emacs 继承终端 PATH
;; 解决 clangd / g++ / pip 包在 Emacs 里找不到的问题
;; -----------------------------
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns x))
  :config
  (dolist (var '("PATH" "MANPATH" "LIBRARY_PATH" "CPATH"
                 "C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"))
    (add-to-list 'exec-path-from-shell-variables var))
  (exec-path-from-shell-initialize))
;; Markdown：稳定优先
;; 不用 md-ts-mode，避免和 markdown-mode 生态冲突
;; -----------------------------
(use-package markdown-mode
  :mode ("\\.md\\'" . gfm-mode)
  :mode ("\\.mkd\\'" . gfm-mode)
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

;; -----------------------------
;; Tree-sitter：兼容版
;; 不使用 treesit-ready-p
;; -----------------------------
(defun my/treesit-ok-p (lang)
  "Return non-nil when tree-sitter and LANG grammar are both available."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (fboundp 'treesit-language-available-p)
       (treesit-language-available-p lang)))

(when (and (fboundp 'treesit-available-p)
           (treesit-available-p))

  ;; grammar 来源
  (setq treesit-language-source-alist
        '((bash       "https://github.com/tree-sitter/tree-sitter-bash")
          (c          "https://github.com/tree-sitter/tree-sitter-c")
          (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")
          (css        "https://github.com/tree-sitter/tree-sitter-css")
          (go         "https://github.com/tree-sitter/tree-sitter-go")
          (html       "https://github.com/tree-sitter/tree-sitter-html")
          (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
          (json       "https://github.com/tree-sitter/tree-sitter-json")
          (python     "https://github.com/tree-sitter/tree-sitter-python")
          (rust       "https://github.com/tree-sitter/tree-sitter-rust")
          (toml       "https://github.com/tree-sitter/tree-sitter-toml")
          (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
          (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
          (yaml       "https://github.com/ikatyang/tree-sitter-yaml")))

  ;; 手动安装 grammar
  (defun my/treesit-install-grammars ()
    "Install missing tree-sitter grammars."
    (interactive)
    (dolist (lang '(bash c cpp css go html javascript json python rust toml tsx typescript yaml))
      (unless (my/treesit-ok-p lang)
        (message "Installing tree-sitter grammar for %s..." lang)
        (condition-case err
            (treesit-install-language-grammar lang)
          (error
           (message "Failed to install %s: %s"
                    lang (error-message-string err)))))))

  ;; 诊断命令
  (defun my/treesit-doctor ()
    "Show tree-sitter status."
    (interactive)
    (message
     "treesit=%s | python=%S | javascript=%S | rust=%S"
     (if (and (fboundp 'treesit-available-p) (treesit-available-p)) "ok" "missing")
     (and (fboundp 'treesit-language-available-p)
          (treesit-language-available-p 'python t))
     (and (fboundp 'treesit-language-available-p)
          (treesit-language-available-p 'javascript t))
     (and (fboundp 'treesit-language-available-p)
          (treesit-language-available-p 'rust t))))

  ;; 老 mode -> ts-mode
  (dolist (spec '((c-mode      c-ts-mode        c)
                  (c++-mode    c++-ts-mode      cpp)
                  (sh-mode     bash-ts-mode     bash)
                  (css-mode    css-ts-mode      css)
                  (js-mode     js-ts-mode       javascript)
                  (json-mode   json-ts-mode     json)
                  (python-mode python-ts-mode   python)
                  (go-mode     go-ts-mode       go)
                  (rust-mode   rust-ts-mode     rust)
                  (yaml-mode   yaml-ts-mode     yaml)))
    (pcase-let ((`(,from ,to ,lang) spec))
      (when (and (fboundp to)
                 (my/treesit-ok-p lang))
        (add-to-list 'major-mode-remap-alist (cons from to)))))

  ;; 扩展名直连
  (when (and (fboundp 'typescript-ts-mode)
             (my/treesit-ok-p 'typescript))
    (add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode)))

  (when (and (fboundp 'tsx-ts-mode)
             (my/treesit-ok-p 'tsx))
    (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode)))

  (when (and (fboundp 'toml-ts-mode)
             (my/treesit-ok-p 'toml))
    (add-to-list 'auto-mode-alist '("\\.toml\\'" . toml-ts-mode))))

(defun compile-and-run-c++ ()
  "编译并运行当前C++文件（Windows兼容版）"
  (interactive)
  (save-buffer)
  (let* ((file (buffer-file-name))
         (output (file-name-sans-extension file))
         ;; Windows 用 && 连接，可执行文件加 .exe
         (cmd (if (eq system-type 'windows-nt)
                  (format "g++ -std=c++17 -O2 -Wall \"%s\" -o \"%s\" && \"%s.exe\""
                          file output output)
                (format "g++ -std=c++17 -O2 -Wall \"%s\" -o \"%s\" && \"%s\" && rm \"%s\""
                        file output output output))))
    (compile cmd)))

(defun my/cpp-mode-setup ()
  "My C/C++ editing setup."
  (local-set-key (kbd "C-c r") #'compile-and-run-c++)
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  ;; eglot 诊断默认走 flymake；在 C/C++ 里关闭 flycheck，避免冲突
  (flycheck-mode -1)
  (flymake-mode 1)
  ;; 保存自动格式化（clang-format）
  (add-hook 'before-save-hook #'clang-format-buffer nil t))

(add-hook 'c++-mode-hook #'my/cpp-mode-setup)
(add-hook 'c++-ts-mode-hook #'my/cpp-mode-setup)
(add-hook 'c-mode-hook #'my/cpp-mode-setup)
(add-hook 'c-ts-mode-hook #'my/cpp-mode-setup)


;; =========================
;; macOS 键位
;; command 当 Meta，option 当 Super
;; 更适合大多数 mac 用户
;; =========================
(setq ns-command-modifier 'meta)
(setq ns-option-modifier 'super)

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default c-basic-offset 4)

;; -----------------------------
;; Custom 自动写入区
;; -----------------------------
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages nil))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
