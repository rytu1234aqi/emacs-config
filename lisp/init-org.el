;;; init-org.el --- Powerful Org mode configuration -*- lexical-binding: t; -*-

;;; ------------------------------------------------------------
;;; 1. Basic path setup
;;; ------------------------------------------------------------

(defvar rytu/org-directory (expand-file-name "~/org/")
  "Main Org directory.")

(defconst rytu/org-agenda-file-names
  '("inbox.org" "tasks.org" "projects.org" "habits.org")
  "Org files that should participate in agenda views when they exist.")

(defvar rytu/org-state-directory
  (expand-file-name "var/org/" user-emacs-directory)
  "Directory for generated Org state and database files.")

(defun rytu/org-file (filename)
  "Return FILENAME inside `rytu/org-directory'."
  (expand-file-name filename rytu/org-directory))

(make-directory rytu/org-directory t)
(make-directory (rytu/org-file "roam/") t)
(make-directory rytu/org-state-directory t)

(defun rytu/org-refresh-agenda-files (&rest _)
  "Refresh `org-agenda-files', excluding files that do not exist yet."
  (setq org-agenda-files
        (delq nil
              (mapcar (lambda (name)
                        (let ((file (rytu/org-file name)))
                          (when (file-exists-p file) file)))
                      rytu/org-agenda-file-names))))


;;; ------------------------------------------------------------
;;; 2. Org core
;;; ------------------------------------------------------------

(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :bind
  (("C-c a" . org-agenda)
   ("C-c c" . org-capture)
   ("C-c n l" . org-store-link))
  :hook
  ((org-mode . visual-line-mode)
   (org-mode . rytu/org-mode-setup))
  :config
  ;; Basic files
  (setq org-directory rytu/org-directory
        org-default-notes-file (rytu/org-file "inbox.org"))
  (rytu/org-refresh-agenda-files)
  (unless (advice-member-p #'rytu/org-refresh-agenda-files 'org-agenda)
    (advice-add 'org-agenda :before #'rytu/org-refresh-agenda-files))
  (add-hook 'org-capture-after-finalize-hook #'rytu/org-refresh-agenda-files)

  ;; Appearance
  (setq org-startup-indented t
        org-hide-emphasis-markers t
        org-pretty-entities t
        org-startup-with-inline-images t
        org-image-actual-width '(600)
        org-ellipsis " ▾"
        org-auto-align-tags nil
        org-tags-column 0
        org-fold-catch-invisible-edits 'show-and-error
        org-special-ctrl-a/e t
        org-special-ctrl-k t
        org-return-follows-link t)

  ;; TODO workflow
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "DOING(i)" "WAIT(w@/!)" "MAYBE(m)" "|" "DONE(d!)" "CANCELLED(c@)")))

  (setq org-todo-keyword-faces
        '(("TODO"      . (:foreground "#ef4444" :weight bold))
          ("NEXT"      . (:foreground "#f97316" :weight bold))
          ("DOING"     . (:foreground "#3b82f6" :weight bold))
          ("WAIT"      . (:foreground "#a855f7" :weight bold))
          ("MAYBE"     . (:foreground "#64748b" :weight bold))
          ("DONE"      . (:foreground "#22c55e" :weight bold))
          ("CANCELLED" . (:foreground "#6b7280" :weight bold))))

  ;; Tags
  (setq org-tag-alist
        '(("study"   . ?s)
          ("exam"    . ?e)
          ("code"    . ?c)
          ("game"    . ?g)
          ("ai"      . ?a)
          ("unity"   . ?u)
          ("paper"   . ?p)
          ("project" . ?j)
          ("urgent"  . ?x)
          ("idea"    . ?i)))

  ;; Logs
  (setq org-log-done 'time
        org-log-into-drawer t
        org-clock-persist 'history
        org-clock-persist-file
        (expand-file-name "org-clock-save.el" rytu/org-state-directory))

  (org-clock-persistence-insinuate)

  ;; Refile
  (setq org-refile-targets
        `(((,(rytu/org-file "tasks.org")
            ,(rytu/org-file "projects.org")
            ,(rytu/org-file "notes.org"))
           :maxlevel . 3)))

  (setq org-outline-path-complete-in-steps nil
        org-refile-use-outline-path 'file)

  ;; Archive
  (setq org-archive-location
        (concat (rytu/org-file "archive.org") "::* From %s"))

  ;; Agenda
  (setq org-agenda-span 'week
        org-agenda-start-on-weekday nil
        org-agenda-window-setup 'current-window
        org-agenda-tags-column 0
        org-agenda-block-separator ?─
        org-agenda-current-time-string "← now"
        org-agenda-skip-deadline-if-done t
        org-agenda-skip-scheduled-if-done t
        org-agenda-include-diary nil)

  ;; Habit
  (require 'org-habit)
  (setq org-habit-show-habits-only-for-today nil
        org-habit-graph-column 60)

  ;; Capture templates
  (setq org-capture-templates
        `(("t" "Task / 任务" entry
           (file ,(rytu/org-file "inbox.org"))
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :empty-lines 1)

          ("n" "Note / 普通笔记" entry
           (file ,(rytu/org-file "notes.org"))
           "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n%a\n"
           :empty-lines 1)

          ("p" "Project / 项目" entry
           (file ,(rytu/org-file "projects.org"))
           "* TODO %? :project:\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n** 目标\n\n** 下一步\n- [ ] \n\n** 资料\n"
           :empty-lines 1)

          ("j" "Journal / 日记" entry
           (file+olp+datetree ,(rytu/org-file "journal.org"))
           "* %U\n\n%?\n"
           :empty-lines 1)

          ("i" "Idea / 灵感" entry
           (file ,(rytu/org-file "inbox.org"))
           "* MAYBE %? :idea:\n:PROPERTIES:\n:CREATED: %U\n:END:\n"
           :empty-lines 1)))

  ;; Babel: 代码块执行
  ;; 安全起见，默认执行前询问。
  (setq org-confirm-babel-evaluate t)

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (python     . t)
     (shell      . t)
     (C          . t)))

  ;; Export
  (setq org-export-with-toc t
        org-export-with-section-numbers t)

  ;; 自定义 Agenda 视图
  (setq org-agenda-custom-commands
        '(("d" "Dashboard"
           ((agenda "" ((org-agenda-span 1)))
            (todo "NEXT"
                  ((org-agenda-overriding-header "Next Actions")))
            (todo "DOING"
                  ((org-agenda-overriding-header "Doing Now")))
            (tags-todo "+urgent"
                       ((org-agenda-overriding-header "Urgent")))
            (tags-todo "+project"
                       ((org-agenda-overriding-header "Projects")))))

          ("w" "Weekly Review"
           ((agenda "" ((org-agenda-span 7)))
            (todo "WAIT"
                  ((org-agenda-overriding-header "Waiting")))
            (todo "MAYBE"
                  ((org-agenda-overriding-header "Maybe / Ideas")))))

          ("s" "Study"
           ((tags-todo "+study")
            (tags-todo "+exam")
            (tags-todo "+paper")))

          ("g" "Game / AI"
           ((tags-todo "+game")
            (tags-todo "+unity")
            (tags-todo "+ai"))))))


(defun rytu/org-mode-setup ()
  "Personal Org mode UI setup."
  (setq-local line-spacing 0.15)
  (display-line-numbers-mode -1))


;;; ------------------------------------------------------------
;;; 3. Better visual style
;;; ------------------------------------------------------------

(use-package org-modern
  :after org
  :hook
  ((org-mode . org-modern-mode)
   (org-agenda-finalize . org-modern-agenda))
  :config
  (setq org-modern-star '("◉" "○" "✸" "✿" "◆" "▶")
        org-modern-hide-stars nil
        org-modern-table t
        org-modern-list '((43 . "◦")
                          (45 . "•")
                          (42 . "◆"))
        org-modern-todo t
        org-modern-tag t
        org-modern-priority t
        ;; org-modern-checkbox 必须是列表或 nil，不能是 t
        org-modern-checkbox '((?X . "☑")
                              (?- . "☐")
                              (?\s . "☐"))
        org-modern-block-name t
        org-modern-keyword t))


(use-package org-appear
  :after org
  :hook (org-mode . org-appear-mode)
  :config
  (setq org-appear-autolinks t
        org-appear-autoemphasis t
        org-appear-autosubmarkers t))


(defcustom rytu/org-valign-max-buffer-size 200000
  "Maximum Org buffer size for enabling valign automatically."
  :type 'integer
  :group 'org)

(defun rytu/org-maybe-enable-valign ()
  "Enable valign unless the current Org buffer is unusually large."
  (when (and (display-graphic-p)
             (< (buffer-size) rytu/org-valign-max-buffer-size))
    (valign-mode 1)))

(use-package valign
  :hook (org-mode . rytu/org-maybe-enable-valign))


;;; ------------------------------------------------------------
;;; 4. Better agenda grouping
;;; ------------------------------------------------------------

(use-package org-super-agenda
  :after org
  :hook (org-agenda-mode . org-super-agenda-mode)
  :config
  (setq org-super-agenda-groups
        '((:name "Today / 今天"
           :time-grid t
           :date today
           :scheduled today)

          (:name "Important / 重要"
           :priority "A")

          (:name "Overdue / 已逾期"
           :deadline past)

          (:name "Due Soon / 临近截止"
           :deadline future)

          (:name "Doing / 正在做"
           :todo "DOING")

          (:name "Next / 下一步"
           :todo "NEXT")

          (:name "Waiting / 等待中"
           :todo "WAIT")

          (:name "Projects / 项目"
           :tag "project")

          (:name "Study / 学习"
           :tag "study")

          (:discard (:todo "DONE")))))


;;; ------------------------------------------------------------
;;; 5. TOC support
;;; ------------------------------------------------------------

(use-package toc-org
  :hook (org-mode . toc-org-mode))


;;; ------------------------------------------------------------
;;; 6. Org-roam: 双链知识库
;;; ------------------------------------------------------------

;; 临时用 org-roam 默认模板测试
(setq org-roam-capture-templates
      '(("d" "default" plain "%?"
         :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                             "#+title: ${title}\n")
         :unnarrowed t)))

(use-package org-roam
  :custom
  (org-roam-directory (file-truename (rytu/org-file "roam/")))
  (org-roam-db-location
   (expand-file-name "org-roam.db" rytu/org-state-directory))
  (org-roam-completion-everywhere t)
  :bind
  (("C-c n f" . org-roam-node-find)
   ("C-c n i" . org-roam-node-insert)
   ("C-c n c" . org-roam-capture)
   ("C-c n b" . org-roam-buffer-toggle)
   ("C-c n g" . org-roam-graph))
  :config
  (org-roam-db-autosync-mode))


;;; ------------------------------------------------------------
;;; 7. Useful Org keybindings
;;; ------------------------------------------------------------

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c C-x C-r") #'org-refile)
  (define-key org-mode-map (kbd "C-c C-x C-a") #'org-archive-subtree)
  (define-key org-mode-map (kbd "C-c C-x C-i") #'org-clock-in)
  (define-key org-mode-map (kbd "C-c C-x C-o") #'org-clock-out)
  (define-key org-mode-map (kbd "C-c C-x C-j") #'org-clock-goto))


(provide 'init-org)

;;; init-org.el ends here
