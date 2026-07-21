;;; init-dashboard.el --- Start page powered by dashboard.el -*- lexical-binding: t; -*-

;;; 基于 dashboard.el 的起始页：图片横幅 + Nerd 图标 + 最近文件/项目/Agenda。
;;; 保留旧自定义起始页的快捷命令与按键习惯（a/t/w/c/f/p/r/e/g）。

(require 'dashboard)
(require 'nerd-icons)

(defgroup rytu/dashboard nil
  "Personal start-page settings."
  :group 'convenience)

(defcustom rytu/dashboard-banner
  (expand-file-name "images/emacs-logo.png" user-emacs-directory)
  "PNG banner displayed at the top of the start page."
  :type 'file
  :group 'rytu/dashboard)

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
      dashboard-startup-banner rytu/dashboard-banner
      dashboard-center-content t
      dashboard-vertically-center-content t
      ;; 快捷键提示关闭：下方会绑定自己的按键，避免提示与实际行为不符。
      dashboard-show-shortcuts nil
      dashboard-item-shortcuts nil
      dashboard-items '((recents  . 8)
                        (projects . 5)
                        (agenda   . 5))
      dashboard-item-names '(("Recent Files:"              . "最近文件")
                             ("Projects:"                  . "项目")
                             ("Agenda for today:"          . "今日 Agenda")
                             ("Agenda for the coming week:" . "未来一周 Agenda"))
      dashboard-init-info #'rytu/dashboard--init-info
      dashboard-footer-messages
      '("按 g 刷新 · M-x rytu/dashboard-open 可随时重新打开"))

;;; 图标（Symbols Nerd Font Mono，需已安装 NFM.ttf）
(setq dashboard-icon-type 'nerd-icons
      dashboard-set-heading-icons t
      dashboard-set-file-icons t
      dashboard-heading-icons '((recents  . "nf-oct-history")
                                (projects . "nf-oct-rocket")
                                (agenda   . "nf-oct-calendar"))
      dashboard-agenda-item-icon
      (nerd-icons-octicon "nf-oct-dot_fill" :height 1.0 :v-adjust 0.01)
      dashboard-footer-icon
      (nerd-icons-sucicon "nf-custom-emacs"
                          :height 1.1 :v-adjust -0.05
                          :face 'dashboard-footer-icon-face))

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
        dashboard-insert-footer)
      dashboard-navigator-buttons
      `(((,(nerd-icons-octicon "nf-oct-calendar" :height 1.1)
          "Agenda 总览" "打开 Agenda 菜单"
          (lambda (&rest _) (call-interactively #'org-agenda)))
         (,(nerd-icons-octicon "nf-oct-checklist" :height 1.1)
          "今日安排" "打开今日 Agenda 面板"
          (lambda (&rest _) (rytu/dashboard-agenda-today)))
         (,(nerd-icons-octicon "nf-oct-pencil" :height 1.1)
          "快速记录" "快速记录任务或笔记"
          (lambda (&rest _) (call-interactively #'org-capture))))
        ((,(nerd-icons-octicon "nf-oct-history" :height 1.1)
          "最近文件" "选择最近打开的文件"
          (lambda (&rest _) (rytu/dashboard-recent-files)))
         (,(nerd-icons-octicon "nf-oct-gear" :height 1.1)
          "编辑配置" "打开 init.el"
          (lambda (&rest _) (rytu/dashboard-edit-config))))))

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

(setq initial-buffer-choice (lambda () (get-buffer-create dashboard-buffer-name)))
(dashboard-setup-startup-hook)

(provide 'init-dashboard)
;;; init-dashboard.el ends here
