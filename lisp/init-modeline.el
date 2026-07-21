;;; init-modeline.el --- Compact project and language status -*- lexical-binding: t; -*-

(require 'use-package)

(use-package doom-modeline
  :ensure t
  :demand t
  :init
  (setq doom-modeline-height 28
        doom-modeline-bar-width 3
        doom-modeline-hud nil
        doom-modeline-window-width-limit 80
        doom-modeline-project-detection 'project
        doom-modeline-buffer-file-name-style 'relative-to-project
        doom-modeline-buffer-name t
        doom-modeline-highlight-modified-buffer-name t
        doom-modeline-enable-buffer-position t
        doom-modeline-position-column-line-format '("Ln %l, Col %c")
        doom-modeline-column-zero-based nil
        doom-modeline-percent-position nil
        doom-modeline-selection-info t
        doom-modeline-enable-word-count nil
        ;; 和 VS Code 一样直接显示编码、换行符与 Spaces/Tabs 宽度。
        doom-modeline-buffer-encoding t
        doom-modeline-indent-info t
        doom-modeline-minor-modes nil
        doom-modeline-project-name t
        doom-modeline-workspace-name t
        doom-modeline-persp-name nil
        doom-modeline-vcs-max-length 24
        ;; 无图标阶段使用聚合数，避免干净文件常驻三组 ASCII "! 0"。
        doom-modeline-check 'simple
        doom-modeline-lsp t
        doom-modeline-repl t
        doom-modeline-env-version nil
        doom-modeline-modal nil
        doom-modeline-time nil
        ;; 图标包已经存在，但字体要到阶段 5 才统一安装与校验。
        doom-modeline-icon nil
        doom-modeline-unicode-fallback nil)
  :config
  (doom-modeline-mode 1))

(provide 'init-modeline)
;;; init-modeline.el ends here
