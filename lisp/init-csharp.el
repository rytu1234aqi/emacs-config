;;; init-csharp.el --- C# language tooling with lsp-mode -*- lexical-binding: t; -*-

;;; Commentary:
;; C# intentionally uses lsp-mode rather than the global Eglot setup.  The
;; stable default is csharp-ls; the official Roslyn language server remains an
;; opt-in per-project backend while its distribution is prerelease.

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'subr-x)
(require 'init-unity)

(declare-function lsp-disconnect "lsp-mode")
(declare-function lsp-f-canonical "lsp-mode")
(declare-function lsp-format-buffer "lsp-mode")
(declare-function lsp-session "lsp-mode")
(declare-function lsp-session-folders "lsp-mode")
(declare-function lsp-workspace-folders-add "lsp-mode")
(declare-function lsp-workspace-restart "lsp-mode")
(declare-function lsp-workspaces "lsp-mode")
(declare-function lsp-ui-mode "lsp-ui" (&optional arg))
(declare-function my/tab-dwim "init" ())

(defgroup my/csharp nil
  "C# editing and language-server integration."
  :group 'languages
  :prefix "my/csharp-")

(defcustom my/csharp-default-backend 'csharp-ls
  "Default lsp-mode backend for C# buffers."
  :type '(choice (const :tag "csharp-ls (stable)" csharp-ls)
                 (const :tag "Official Roslyn language server"
                        csharp-roslyn))
  :group 'my/csharp)

(defcustom my/csharp-project-backends nil
  "Per-project overrides for the C# language-server backend.

Use `my/csharp-select-backend' to update this value safely."
  :type '(alist :key-type directory
                :value-type (choice (const csharp-ls)
                                    (const csharp-roslyn)))
  :group 'my/csharp)

(defcustom my/csharp-lsp-idle-delay 0.5
  "Seconds of idle time before lsp-mode sends buffered changes."
  :type 'number
  :group 'my/csharp)

(defcustom my/csharp-indent-width 4
  "Width of one logical indentation tab in C# buffers."
  :type 'integer
  :group 'my/csharp)

;; Language servers can return large JSON messages, especially while a Unity
;; solution is loading.  Larger process chunks and a less aggressive garbage
;; collector avoid repeated process-filter and GC pauses while typing.
(setq read-process-output-max
      (max read-process-output-max (* 1024 1024)))
(setq gc-cons-threshold
      (max gc-cons-threshold (* 64 1024 1024)))

(defun my/csharp--normalize-root (root)
  "Return a stable directory key for ROOT."
  (when root
    (file-name-as-directory (expand-file-name root))))

(defun my/csharp--project-root (&optional root)
  "Return ROOT or the current Unity/project.el root."
  (my/csharp--normalize-root
   (or root
       (my/unity-current-root t)
       (when-let ((project (project-current nil)))
         (project-root project))
       default-directory)))

(defun my/csharp-current-backend (&optional root)
  "Return the selected C# backend for ROOT or the current project."
  (let ((root (my/csharp--project-root root)))
    (or (alist-get root my/csharp-project-backends nil nil #'string-equal)
        my/csharp-default-backend)))

(defun my/csharp--configure-project ()
  "Set buffer-local language-server choices before starting lsp-mode."
  (let ((backend (my/csharp-current-backend)))
    ;; Restrict the C# buffer to one client so OmniSharp/csharp-ls/Roslyn never
    ;; race each other for the same document.
    (setq-local lsp-enabled-clients (list backend))
    (when-let ((solution (my/unity-project-solution
                          (my/unity-current-root t))))
      (setq-local lsp-csharp-solution-file solution))))

(defun my/csharp--ensure-workspace-root ()
  "Register the current project root with lsp-mode without a first-use prompt."
  (when-let* ((root (or (my/unity-current-root t)
                        (when-let ((project (project-current nil)))
                          (project-root project))))
              ((require 'lsp-mode nil t)))
    (let ((canonical (lsp-f-canonical root))
          (session (lsp-session)))
      (unless (member canonical (lsp-session-folders session))
        (lsp-workspace-folders-add root)))))

(defun my/csharp--buffer-p ()
  "Return non-nil when the current buffer is a C# source buffer."
  (derived-mode-p 'csharp-mode 'csharp-ts-mode))

(defun my/csharp--same-root-p (left right)
  "Return non-nil when directory roots LEFT and RIGHT are equal."
  (and left right
       (string-equal (downcase (my/csharp--normalize-root left))
                     (downcase (my/csharp--normalize-root right)))))

(defun my/csharp--project-buffers (&optional root)
  "Return live C# buffers belonging to ROOT or the current project."
  (let ((root (my/csharp--project-root root)))
    (cl-remove-if-not
     (lambda (buffer)
       (with-current-buffer buffer
         (and (my/csharp--buffer-p)
              (my/csharp--same-root-p root (my/csharp--project-root)))))
     (buffer-list))))

(defun my/csharp-restart-workspace (&optional disconnect)
  "Restart the current project's C# workspace.

With optional DISCONNECT, drop the existing client first.  Backend changes use
this mode so lsp-mode selects a different registered client."
  (interactive)
  (let* ((root (my/csharp--project-root))
         (buffers (my/csharp--project-buffers root)))
    (if (null buffers)
        (message "No open C# buffer belongs to %s" root)
      (dolist (buffer buffers)
        (with-current-buffer buffer
          (my/csharp--configure-project)))
      (with-current-buffer (car buffers)
        (cond
         (disconnect
          (when (bound-and-true-p lsp-mode)
            (ignore-errors (lsp-disconnect)))
          (lsp-deferred))
         ((and (bound-and-true-p lsp-mode)
               (ignore-errors (lsp-workspaces)))
          (lsp-workspace-restart))
         (t
          (lsp-deferred)))))))

(defun my/csharp-select-backend (backend)
  "Select and persist the C# language-server BACKEND for this project."
  (interactive
   (list (intern
          (completing-read
           "C# backend: " '("csharp-ls" "csharp-roslyn") nil t nil nil
           (symbol-name (my/csharp-current-backend))))))
  (let ((root (my/csharp--project-root)))
    (setf (alist-get root my/csharp-project-backends nil nil #'string-equal)
          backend)
    (customize-save-variable 'my/csharp-project-backends
                             my/csharp-project-backends)
    (message "C# backend for %s: %s" root backend)
    (my/csharp-restart-workspace t)))

(defun my/csharp--format-before-save ()
  "Format the current buffer when a C# LSP workspace is active."
  (when (and (bound-and-true-p lsp-mode)
             (ignore-errors (lsp-workspaces)))
    (lsp-format-buffer)))

(define-minor-mode my/csharp-format-on-save-mode
  "Format the current C# buffer through LSP before every save.

This is opt-in to avoid surprising whole-file changes in existing Unity
projects."
  :lighter " C#Fmt"
  (if my/csharp-format-on-save-mode
      (add-hook 'before-save-hook #'my/csharp--format-before-save nil t)
    (remove-hook 'before-save-hook #'my/csharp--format-before-save t)))

(defun my/csharp-toggle-rich-ui ()
  "Toggle the optional lsp-ui documentation popup for this C# buffer.

Sideline diagnostics and code actions remain disabled because they redraw
line-end overlays after edits and duplicate the lighter Flymake interface."
  (interactive)
  (unless (my/csharp--buffer-p)
    (user-error "This command is only available in a C# buffer"))
  (unless (require 'lsp-ui nil t)
    (user-error "lsp-ui is not installed"))
  (let ((enable (not (bound-and-true-p lsp-ui-mode))))
    (setq-local lsp-ui-doc-enable enable
                lsp-ui-sideline-enable nil
                lsp-ui-sideline-show-code-actions nil)
    (lsp-ui-mode (if enable 1 -1)))
  (message "C# hover documentation %s"
           (if (bound-and-true-p lsp-ui-mode) "enabled" "disabled")))

(defun my/csharp-disable-sideline-ui ()
  "Disable persistent lsp-ui overlays in a C# buffer.

Completion documentation is handled by Corfu Popupinfo, while Flymake keeps
diagnostics as lightweight underlines and fringe indicators."
  (when (my/csharp--buffer-p)
    (setq-local lsp-ui-doc-enable nil
                lsp-ui-sideline-enable nil
                lsp-ui-sideline-show-diagnostics nil
                lsp-ui-sideline-show-hover nil
                lsp-ui-sideline-show-code-actions nil)
    (when (and (bound-and-true-p lsp-ui-mode)
               (fboundp 'lsp-ui-mode))
      (lsp-ui-mode -1))))

(defun my/csharp-backward-delete ()
  "Delete one logical tab stop in C# indentation.

Inside leading whitespace, delete back to the previous
`my/csharp-indent-width' column.  Outside indentation, preserve the normal
one-character Backspace behavior."
  (interactive)
  (cond
   ((use-region-p)
    (delete-region (region-beginning) (region-end)))
   ((and (> (point) (line-beginning-position))
         (<= (point)
             (save-excursion
               (back-to-indentation)
               (point))))
    (let* ((end (point))
           (column (current-column))
           (width (max 1 my/csharp-indent-width))
           (remainder (% column width))
           (columns (if (zerop remainder) width remainder))
           start)
      (save-excursion
        (move-to-column (max 0 (- column columns)))
        (setq start (point)))
      (delete-region start end)))
   (t
    (delete-backward-char 1))))

(defun my/csharp-doctor ()
  "Display C#, Unity, Tree-sitter, and LSP configuration status."
  (interactive)
  (let* ((root (my/csharp--project-root))
         (unity-root (my/unity-current-root t))
         (solution (and unity-root (my/unity-project-solution unity-root))))
    (with-help-window "*C# Doctor*"
      (princ (format "Project:       %s\n" root))
      (princ (format "Unity project: %s\n" (or unity-root "no")))
      (princ (format "Solution:      %s\n" (or solution "automatic/not found")))
      (princ (format "Backend:       %s\n" (my/csharp-current-backend root)))
      (princ (format "csharp-ls:     %s\n"
                     (or (executable-find "csharp-ls") "not installed")))
      (princ (format "dotnet:        %s\n"
                     (or (executable-find "dotnet") "not installed")))
      (princ (format "Tree-sitter:   %s\n"
                     (if (and (fboundp 'my/treesit-ok-p)
                              (my/treesit-ok-p 'c-sharp))
                         "c-sharp ready"
                       "c-sharp unavailable; csharp-mode fallback active")))
      (princ (format "LSP active:    %s\n"
                     (if (and (bound-and-true-p lsp-mode)
                              (ignore-errors (lsp-workspaces)))
                         "yes"
                       "no")))
      (princ (format "LSP idle:      %.2fs\n" my/csharp-lsp-idle-delay))
      (princ (format "GC threshold:  %.0f MiB\n"
                     (/ gc-cons-threshold 1048576.0)))
      (princ (format "Rich UI:       %s\n"
                     (if (bound-and-true-p lsp-ui-mode)
                         "enabled"
                       "disabled (lightweight default)"))))))

(defun my/csharp-mode-setup ()
  "Configure editing, diagnostics, and LSP for C# and Unity source files."
  (setq-local c-basic-offset my/csharp-indent-width)
  (setq-local tab-width my/csharp-indent-width)
  (setq-local indent-tabs-mode nil)
  (when (boundp 'csharp-ts-mode-indent-offset)
    (setq-local csharp-ts-mode-indent-offset my/csharp-indent-width))
  ;; Bind both terminal TAB (C-i) and the GUI <tab> event explicitly.  Corfu's
  ;; higher-precedence popup map accepts a candidate when completion is active.
  (local-set-key (kbd "TAB") #'my/tab-dwim)
  (local-set-key (kbd "<tab>") #'my/tab-dwim)
  ;; Treat a run of indentation spaces as one logical tab for Backspace.
  (local-set-key (kbd "DEL") #'my/csharp-backward-delete)
  (local-set-key (kbd "<backspace>") #'my/csharp-backward-delete)
  (when (fboundp 'flycheck-mode)
    (flycheck-mode -1))
  (flymake-mode 1)
  (my/csharp-disable-sideline-ui)
  (my/csharp--configure-project)
  (my/csharp--ensure-workspace-root)
  (if (or (not (eq (my/csharp-current-backend) 'csharp-ls))
          (executable-find "csharp-ls"))
      (lsp-deferred)
    (message "C# LSP unavailable: run `dotnet tool install --global csharp-ls`")))

(use-package csharp-mode
  :mode "\\.cs\\'")

(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l"
        ;; lsp-completion-mode still installs its CAPF when this is :none;
        ;; :none only prevents its Company auto-configuration, leaving Corfu
        ;; as the popup frontend without a misleading startup warning.
        lsp-completion-provider :none
        lsp-diagnostics-provider :flymake
        lsp-idle-delay my/csharp-lsp-idle-delay
        lsp-log-io nil
        lsp-keep-workspace-alive nil
        ;; Keep the default editing path light.  These decorations issue
        ;; additional requests or redraw overlays after edits and cursor moves.
        lsp-semantic-tokens-enable nil
        lsp-inlay-hint-enable nil
        lsp-lens-enable nil
        lsp-headerline-breadcrumb-enable nil
        lsp-enable-symbol-highlighting nil
        lsp-enable-on-type-formatting nil
        lsp-eldoc-enable-hover nil
        lsp-enable-file-watchers t
        lsp-format-buffer-on-save nil
        lsp-csharp-csharpls-use-dotnet-tool t
        lsp-csharp-csharpls-use-local-tool nil)
  :hook ((csharp-mode . my/csharp-mode-setup)
         (csharp-ts-mode . my/csharp-mode-setup))
  :config
  (add-hook 'lsp-mode-hook #'my/csharp-disable-sideline-ui)
  (dolist (regexp '("[/\\\\]Library\\'"
                    "[/\\\\]Temp\\'"
                    "[/\\\\]Logs\\'"
                    "[/\\\\][Oo]bj\\'"
                    "[/\\\\]Builds?\\'"
                    "[/\\\\]UserSettings\\'"
                    "[/\\\\]\\.vs\\'"
                    "[/\\\\]\\.idea\\'"))
    (add-to-list 'lsp-file-watch-ignored-directories regexp))
  ;; Extend lsp-mode's normal C-c l command map with project-specific actions.
  (define-key lsp-command-map (kbd "b") #'my/csharp-select-backend)
  (define-key lsp-command-map (kbd "F") #'my/csharp-format-on-save-mode)
  (define-key lsp-command-map (kbd "U") #'my/unity-select-solution)
  (define-key lsp-command-map (kbd "R") #'my/csharp-restart-workspace)
  (define-key lsp-command-map (kbd "u") #'my/csharp-toggle-rich-ui)
  (define-key lsp-command-map (kbd "?") #'my/csharp-doctor))

(use-package lsp-ui
  :after lsp-mode
  :commands lsp-ui-mode
  :custom
  (lsp-ui-doc-enable nil)
  (lsp-ui-doc-delay 0.6)
  (lsp-ui-doc-show-with-cursor nil)
  (lsp-ui-doc-show-with-mouse t)
  (lsp-ui-sideline-enable nil)
  (lsp-ui-sideline-show-diagnostics nil)
  (lsp-ui-sideline-show-hover nil)
  (lsp-ui-sideline-show-code-actions nil))

(use-package consult-lsp
  :after (consult lsp-mode)
  :commands consult-lsp-symbols)

(use-package treemacs
  :commands treemacs)

(use-package lsp-treemacs
  :after (lsp-mode treemacs)
  :commands (lsp-treemacs-errors-list
             lsp-treemacs-symbols
             lsp-treemacs-java-deps-list))

(provide 'init-csharp)
;;; init-csharp.el ends here
