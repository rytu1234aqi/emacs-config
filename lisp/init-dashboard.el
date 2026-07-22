;;; init-dashboard.el --- Start page powered by dashboard.el -*- lexical-binding: t; -*-

;;; 基于 dashboard.el 的起始页：图片横幅 + 可选 Nerd 图标 + 最近文件/项目/Agenda。
;;; 保留旧自定义起始页的快捷命令与按键习惯（a/t/w/c/f/p/r/e/g）。

(require 'init-icons)
(require 'use-package)

;; 这两个包过去只出现在 `package-selected-packages' 中；那个变量只负责
;; 记录/保护包，并不会安装它们。这里显式声明依赖，保证全新环境可重建。
(use-package dashboard
  :ensure t
  :demand t)

(defgroup rytu/dashboard nil
  "Personal start-page settings."
  :group 'convenience)

(defcustom rytu/dashboard-banner
  (expand-file-name "images/emacs-logo.png" user-emacs-directory)
  "PNG banner displayed at the top of the start page."
  :type 'file
  :group 'rytu/dashboard)

(defun rytu/dashboard--icon (renderer name fallback &rest properties)
  "Render NAME with RENDERER, or return FALLBACK when its font is unavailable."
  (if (my/icons-available-p)
      (apply renderer name properties)
    fallback))

;;; ---------------------------------------------------------------------------
;;; 快捷命令（沿用旧自定义起始页）
;;; ---------------------------------------------------------------------------

(defun rytu/dashboard-agenda-today ()
  "Open the custom Agenda dashboard for today."
  (interactive)
  (org-agenda nil "d"))

(defun rytu/dashboard-agenda-week ()
  "Open the custom Agenda view for the next seven days."
  (interactive)
  (org-agenda nil "w"))

(defun rytu/dashboard-recent-files ()
  "Open the preferred recent-file picker."
  (interactive)
  (if (fboundp 'consult-recent-file)
      (call-interactively #'consult-recent-file)
    (call-interactively #'recentf-open-files)))

(defun rytu/dashboard-edit-config ()
  "Open the active Emacs configuration file."
  (interactive)
  (find-file
   (or user-init-file
       (expand-file-name "init.el" user-emacs-directory))))

(defun rytu/dashboard-open ()
  "Open (or refresh) the start page."
  (interactive)
  (dashboard-open))

(defun rytu/dashboard-refresh ()
  "Refresh the start page."
  (interactive)
  (dashboard-refresh-buffer))

(defun rytu/dashboard--init-info ()
  "Return the one-line session summary shown above the footer."
  (format "%d 个扩展包  ·  启动 %s  ·  主题 %s"
          (dashboard-init--packages-count)
          (string-replace "seconds" "秒" (dashboard-init--time))
          (if custom-enabled-themes
              (mapconcat #'symbol-name custom-enabled-themes ", ")
            "default")))

;;; ---------------------------------------------------------------------------
;;; 页面布局
;;; ---------------------------------------------------------------------------

(setq dashboard-banner-logo-title "Emacs 已就绪，欢迎回来。"
      dashboard-startup-banner (if (file-readable-p rytu/dashboard-banner)
                                   rytu/dashboard-banner
                                 'logo)
      dashboard-center-content t
      dashboard-vertically-center-content t
      ;; 快捷键提示关闭：下方会绑定自己的按键，避免提示与实际行为不符。
      dashboard-show-shortcuts nil
      dashboard-item-shortcuts nil
      ;; Agenda 首次初始化在当前环境约需 8 秒；启动页只保留轻量区块，
      ;; Agenda 仍可通过顶部按钮以及 a/t/w 快捷键按需打开。
      dashboard-items '((recents  . 8)
                        (projects . 5))
      dashboard-projects-backend 'project-el
      dashboard-item-names '(("Recent Files:"              . "最近文件")
                             ("Projects:"                  . "项目")
                             ("Agenda for today:"          . "今日 Agenda")
                             ("Agenda for the coming week:" . "未来一周 Agenda"))
      dashboard-init-info #'rytu/dashboard--init-info
      dashboard-footer-messages
      '("按 g 刷新 · M-x rytu/dashboard-open 可随时重新打开"))

;;; 顶部导航按钮：(icon 标题 帮助 动作)
;;; 1.9.0 起通过 dashboard-startupify-list 显式启用 navigator。
(setq dashboard-startupify-list
      '(dashboard-insert-banner
        dashboard-insert-newline
        dashboard-insert-banner-title
        dashboard-insert-newline
        dashboard-insert-navigator
        dashboard-insert-newline
        dashboard-insert-init-info
        dashboard-insert-items
        dashboard-insert-newline
        dashboard-insert-footer))

(defun rytu/dashboard-configure-icons (&optional frame)
  "Configure Dashboard icons for FRAME and refresh an existing start page."
  (let ((frame (or frame (selected-frame))))
    (with-selected-frame frame
      (let ((icons-available (my/icons-available-p frame)))
        (setq dashboard-display-icons-p icons-available
              dashboard-icon-type 'nerd-icons
              dashboard-set-heading-icons icons-available
              dashboard-set-file-icons icons-available
              dashboard-heading-icons '((recents  . "nf-oct-history")
                                        (projects . "nf-oct-rocket")
                                        (agenda   . "nf-oct-calendar"))
              dashboard-agenda-item-icon
              (rytu/dashboard--icon #'nerd-icons-octicon
                                    "nf-oct-dot_fill" "•"
                                    :height 1.0 :v-adjust 0.01)
              dashboard-footer-icon
              (rytu/dashboard--icon #'nerd-icons-sucicon
                                    "nf-custom-emacs" "λ"
                                    :height 1.1 :v-adjust -0.05
                                    :face 'dashboard-footer-icon-face)
              dashboard-navigator-buttons
              `(((,(rytu/dashboard--icon #'nerd-icons-octicon
                                         "nf-oct-calendar" "◷" :height 1.1)
                  "Agenda 总览" "打开 Agenda 菜单"
                  (lambda (&rest _) (call-interactively #'org-agenda)))
                 (,(rytu/dashboard--icon #'nerd-icons-octicon
                                         "nf-oct-checklist" "✓" :height 1.1)
                  "今日安排" "打开今日 Agenda 面板"
                  (lambda (&rest _) (rytu/dashboard-agenda-today)))
                 (,(rytu/dashboard--icon #'nerd-icons-octicon
                                         "nf-oct-pencil" "✎" :height 1.1)
                  "快速记录" "快速记录任务或笔记"
                  (lambda (&rest _) (call-interactively #'org-capture))))
                ((,(rytu/dashboard--icon #'nerd-icons-octicon
                                         "nf-oct-history" "↶" :height 1.1)
                  "最近文件" "选择最近打开的文件"
                  (lambda (&rest _) (rytu/dashboard-recent-files)))
                 (,(rytu/dashboard--icon #'nerd-icons-octicon
                                         "nf-oct-gear" "⚙" :height 1.1)
                  "编辑配置" "打开 init.el"
                  (lambda (&rest _) (rytu/dashboard-edit-config))))))))
  (let ((buffer (get-buffer dashboard-buffer-name)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (when (derived-mode-p 'dashboard-mode)
          (dashboard-refresh-buffer)))))))

(defun rytu/dashboard-apply-faces ()
  "Use theme-aware faces with restrained typography on the start page."
  (set-face-attribute 'dashboard-banner-logo-title nil
                      :inherit 'font-lock-function-name-face
                      :height 1.2 :weight 'bold)
  (set-face-attribute 'dashboard-navigator nil
                      :inherit 'font-lock-keyword-face
                      :height 1.03 :weight 'semi-bold)
  (set-face-attribute 'dashboard-heading nil
                      :inherit 'font-lock-keyword-face
                      :height 1.08 :weight 'bold)
  (set-face-attribute 'dashboard-items-face nil
                      :inherit 'default :weight 'normal :underline nil)
  (set-face-attribute 'dashboard-no-items-face nil :inherit 'shadow)
  (set-face-attribute 'dashboard-footer-face nil :inherit 'shadow :height 0.9)
  (set-face-attribute 'dashboard-footer-icon-face nil
                      :inherit 'font-lock-function-name-face :height 1.1))

(rytu/dashboard-configure-icons)
(rytu/dashboard-apply-faces)

;;; 键位：沿用旧起始页习惯
(let ((map dashboard-mode-map))
  (define-key map (kbd "a") #'org-agenda)
  (define-key map (kbd "t") #'rytu/dashboard-agenda-today)
  (define-key map (kbd "w") #'rytu/dashboard-agenda-week)
  (define-key map (kbd "c") #'org-capture)
  (define-key map (kbd "f") #'find-file)
  (define-key map (kbd "p") #'project-switch-project)
  (define-key map (kbd "r") #'rytu/dashboard-recent-files)
  (define-key map (kbd "e") #'rytu/dashboard-edit-config)
  (define-key map (kbd "g") #'dashboard-refresh-buffer))

(setq initial-buffer-choice #'rytu/dashboard-open)
(dashboard-setup-startup-hook)

(provide 'init-dashboard)
;;; init-dashboard.el ends here
