;;; init-dashboard.el --- Personal Emacs start page -*- lexical-binding: t; -*-

(require 'button)
(require 'project)
(require 'subr-x)

(defgroup rytu/dashboard nil
  "Personal Emacs start page."
  :group 'convenience)

(defcustom rytu/dashboard-buffer-name "*Emacs Dashboard*"
  "Name of the personal start-page buffer."
  :type 'string
  :group 'rytu/dashboard)

(defcustom rytu/dashboard-content-width 64
  "Preferred width of the start-page content."
  :type 'integer
  :group 'rytu/dashboard)

(defface rytu/dashboard-logo-face
  '((t (:inherit font-lock-keyword-face :weight bold :height 1.1)))
  "Face used for the Emacs character-art logo."
  :group 'rytu/dashboard)

(defface rytu/dashboard-title-face
  '((t (:inherit variable-pitch :weight bold :height 1.2)))
  "Face used for the welcome message."
  :group 'rytu/dashboard)

(defface rytu/dashboard-heading-face
  '((t (:inherit font-lock-function-name-face :weight bold)))
  "Face used for section headings."
  :group 'rytu/dashboard)

(defface rytu/dashboard-key-face
  '((t (:inherit font-lock-constant-face :weight bold)))
  "Face used for keys on the start page."
  :group 'rytu/dashboard)

(defface rytu/dashboard-muted-face
  '((t (:inherit shadow)))
  "Face used for secondary start-page text."
  :group 'rytu/dashboard)

(defconst rytu/dashboard--logo
  '(" _______ __  __          _____  _____ "
    "|  ____|  \\/  |   /\\   / ____|/ ____|"
    "| |__  | \\  / |  /  \\ | |    | (___  "
    "|  __| | |\\/| | / /\\ \\| |     \\___ \\ "
    "| |____| |  | |/ ____ \\ |____ ____) |"
    "|______|_|  |_/_/    \\_\\_____|_____/ ")
  "Character-art logo displayed on the start page.")

(defvar rytu/dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "a") #'org-agenda)
    (define-key map (kbd "t") #'rytu/dashboard-agenda-today)
    (define-key map (kbd "w") #'rytu/dashboard-agenda-week)
    (define-key map (kbd "c") #'org-capture)
    (define-key map (kbd "f") #'find-file)
    (define-key map (kbd "p") #'project-switch-project)
    (define-key map (kbd "r") #'rytu/dashboard-recent-files)
    (define-key map (kbd "e") #'rytu/dashboard-edit-config)
    (define-key map (kbd "g") #'rytu/dashboard-refresh)
    map)
  "Keymap for `rytu/dashboard-mode'.")

(define-derived-mode rytu/dashboard-mode special-mode "Dashboard"
  "Major mode for the personal Emacs start page."
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t)
  (setq-local cursor-type nil)
  (when (fboundp 'display-line-numbers-mode)
    (display-line-numbers-mode -1))
  (when (fboundp 'hl-line-mode)
    (hl-line-mode -1)))

(defun rytu/dashboard--left-padding (&optional width)
  "Return the padding that centers WIDTH in the selected window."
  (let ((width (or width rytu/dashboard-content-width)))
    (max 2 (/ (- (window-body-width) width) 2))))

(defun rytu/dashboard--insert-padding (&optional width)
  "Insert padding that centers content of WIDTH."
  (insert (make-string (rytu/dashboard--left-padding width) ?\s)))

(defun rytu/dashboard--insert-centered (text &optional face)
  "Insert TEXT centered on its own line, optionally using FACE."
  (rytu/dashboard--insert-padding (string-width text))
  (insert (if face (propertize text 'face face) text) "\n"))

(defun rytu/dashboard--insert-heading (text)
  "Insert a start-page section heading containing TEXT."
  (rytu/dashboard--insert-padding)
  (insert (propertize text 'face 'rytu/dashboard-heading-face) "\n")
  (rytu/dashboard--insert-padding)
  (insert (propertize (make-string (length text) ?─)
                      'face 'rytu/dashboard-muted-face)
          "\n"))

(defun rytu/dashboard--call (command)
  "Call interactive COMMAND from a dashboard button."
  (unless (commandp command)
    (user-error "%s is not available" command))
  (call-interactively command))

(defun rytu/dashboard--insert-action-cell (key label command width)
  "Insert one KEY, LABEL and COMMAND action padded to WIDTH."
  (let ((start (current-column)))
    (insert (propertize (format "[%s] " key)
                        'face 'rytu/dashboard-key-face))
    (insert-text-button
     label
     'action (lambda (_button) (rytu/dashboard--call command))
     'follow-link t
     'face 'link
     'help-echo (format "Run M-x %s" command))
    (insert (make-string (max 1 (- width (- (current-column) start))) ?\s))))

(defun rytu/dashboard--insert-actions (left right)
  "Insert a row containing LEFT and RIGHT action specifications."
  (let ((cell-width (/ rytu/dashboard-content-width 2)))
    (rytu/dashboard--insert-padding)
    (apply #'rytu/dashboard--insert-action-cell
           (append left (list cell-width)))
    (apply #'rytu/dashboard--insert-action-cell
           (append right (list cell-width)))
    (insert "\n")))

(defun rytu/dashboard--insert-key-row (key description)
  "Insert a global KEY and its DESCRIPTION."
  (rytu/dashboard--insert-padding)
  (insert (propertize (format "%-14s" key)
                      'face 'rytu/dashboard-key-face))
  (insert description "\n"))

(defun rytu/dashboard--insert-info-row (label value)
  "Insert one configuration information row with LABEL and VALUE."
  (rytu/dashboard--insert-padding)
  (insert (propertize (format "%-16s" label)
                      'face 'rytu/dashboard-muted-face))
  (insert value "\n"))

(defun rytu/dashboard--init-time ()
  "Return the current Emacs initialization time for display."
  (if (and (boundp 'before-init-time)
           (boundp 'after-init-time)
           after-init-time)
      (format "%.2f seconds"
              (float-time (time-subtract after-init-time before-init-time)))
    "finishing startup"))

(defun rytu/dashboard--theme-name ()
  "Return enabled theme names for display."
  (if custom-enabled-themes
      (mapconcat #'symbol-name custom-enabled-themes ", ")
    "default"))

(defun rytu/dashboard--agenda-file-count ()
  "Return the number of configured Agenda files as a string."
  (number-to-string
   (length (if (listp org-agenda-files) org-agenda-files nil))))

(defun rytu/dashboard--package-count ()
  "Return the number of activated packages as a string."
  (number-to-string
   (length (if (boundp 'package-activated-list)
               package-activated-list
             nil))))

(defun rytu/dashboard--render ()
  "Render the personal start page in the current buffer."
  (let ((inhibit-read-only t)
        (top-padding
         (max 1 (/ (- (window-body-height) 31) 4))))
    (erase-buffer)
    (insert (make-string top-padding ?\n))
    (dolist (line rytu/dashboard--logo)
      (rytu/dashboard--insert-centered line 'rytu/dashboard-logo-face))
    (insert "\n")
    (rytu/dashboard--insert-centered
     "Emacs 已就绪，欢迎回来。"
     'rytu/dashboard-title-face)
    (rytu/dashboard--insert-centered
     "按高亮按键，或点击下面的操作。"
     'rytu/dashboard-muted-face)
    (insert "\n")

    (rytu/dashboard--insert-heading "快捷操作")
    (rytu/dashboard--insert-actions
     '("a" "Agenda" org-agenda)
     '("c" "快速记录" org-capture))
    (rytu/dashboard--insert-actions
     '("f" "打开文件" find-file)
     '("p" "切换项目" project-switch-project))
    (rytu/dashboard--insert-actions
     '("r" "最近文件" rytu/dashboard-recent-files)
     '("e" "编辑配置" rytu/dashboard-edit-config))
    (insert "\n")

    (rytu/dashboard--insert-heading "Agenda 快捷键")
    (rytu/dashboard--insert-key-row "C-c a" "打开 Agenda 菜单")
    (rytu/dashboard--insert-key-row "C-c a, d" "打开今日面板")
    (rytu/dashboard--insert-key-row "C-c a, w" "查看未来七天")
    (rytu/dashboard--insert-key-row "C-c c" "快速记录任务或笔记")
    (insert "\n")

    (rytu/dashboard--insert-heading "配置信息")
    (rytu/dashboard--insert-info-row "Emacs 版本" emacs-version)
    (rytu/dashboard--insert-info-row
     "系统" (format "%s / %s" system-type system-configuration))
    (rytu/dashboard--insert-info-row "启动耗时"
                                     (rytu/dashboard--init-time))
    (rytu/dashboard--insert-info-row "主题"
                                     (rytu/dashboard--theme-name))
    (rytu/dashboard--insert-info-row
     "Org 目录"
     (abbreviate-file-name
      (if (boundp 'org-directory) org-directory "~/org/")))
    (rytu/dashboard--insert-info-row
     "Agenda 文件" (rytu/dashboard--agenda-file-count))
    (rytu/dashboard--insert-info-row
     "已激活包" (rytu/dashboard--package-count))
    (rytu/dashboard--insert-info-row
     "配置文件"
     (abbreviate-file-name
      (or user-init-file
          (expand-file-name "init.el" user-emacs-directory))))
    (insert "\n")
    (rytu/dashboard--insert-centered
     "按 g 刷新 · M-x rytu/dashboard-open 可随时重新打开"
     'rytu/dashboard-muted-face)
    (goto-char (point-min))
    (set-buffer-modified-p nil)))

(defun rytu/dashboard-buffer ()
  "Create, refresh and return the personal start-page buffer."
  (let ((buffer (get-buffer-create rytu/dashboard-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'rytu/dashboard-mode)
        (rytu/dashboard-mode))
      (rytu/dashboard--render))
    buffer))

(defun rytu/dashboard-open ()
  "Open the personal Emacs start page."
  (interactive)
  (switch-to-buffer (rytu/dashboard-buffer)))

(defun rytu/dashboard-refresh ()
  "Refresh the personal Emacs start page."
  (interactive)
  (unless (derived-mode-p 'rytu/dashboard-mode)
    (user-error "This is not an Emacs dashboard buffer"))
  (rytu/dashboard--render))

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

(setq initial-buffer-choice #'rytu/dashboard-buffer)

(provide 'init-dashboard)
;;; init-dashboard.el ends here
