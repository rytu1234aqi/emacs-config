;;; init-icons.el --- Shared Nerd Icons integration -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'init-appearance)
(require 'use-package)

(use-package nerd-icons
  :ensure t
  :demand t)

(defcustom my/ui-use-icons t
  "Use Nerd Icons whenever its font is available in a graphical frame."
  :type 'boolean
  :group 'my/ui)

(defcustom my/ui-icon-font-family nerd-icons-font-family
  "Font family used by Nerd Icons integrations."
  :type 'string
  :group 'my/ui)

(defvar my/icons-available nil
  "Whether the most recently checked graphical frame can render Nerd Icons.")

(defun my/icons-available-p (&optional frame)
  "Return non-nil when FRAME can render the configured Nerd Icons font."
  (let ((frame (or frame (selected-frame))))
    (and my/ui-use-icons
         (display-graphic-p frame)
         (fboundp 'find-font)
         (not (null (ignore-errors
                      (find-font (font-spec :family my/ui-icon-font-family)
                                 frame)))))))

(defun my/icons--configure-completion (&optional frame)
  "Enable completion icons when Marginalia and the icon font are available."
  (when (fboundp 'nerd-icons-completion-mode)
    (nerd-icons-completion-mode
     (if (and (bound-and-true-p marginalia-mode)
              (my/icons-available-p frame))
         1
       -1))))

(defun my/icons--configure-corfu (&optional frame)
  "Select Nerd Icons or the SVG fallback for Corfu in FRAME."
  (when (boundp 'corfu-margin-formatters)
    (let* ((formatters (default-value 'corfu-margin-formatters))
           (known '(nerd-icons-corfu-formatter kind-icon-margin-formatter))
           (others (cl-remove-if (lambda (formatter) (memq formatter known))
                                 formatters))
           (formatter (if (my/icons-available-p frame)
                          #'nerd-icons-corfu-formatter
                        #'kind-icon-margin-formatter)))
      (set-default 'corfu-margin-formatters (cons formatter others)))))

(defun my/icons-dired-maybe-enable ()
  "Toggle `nerd-icons-dired-mode' according to font availability."
  (when (fboundp 'nerd-icons-dired-mode)
    (nerd-icons-dired-mode (if (my/icons-available-p) 1 -1))))

(defun my/icons--refresh-dired-buffers ()
  "Refresh icon state in existing Dired buffers."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'dired-mode)
        (my/icons-dired-maybe-enable)))))

(defun my/refresh-icons (&optional frame)
  "Refresh every loaded icon integration for FRAME."
  (setq my/icons-available (my/icons-available-p frame))
  (my/icons--configure-completion frame)
  (my/icons--configure-corfu frame)
  (my/icons--refresh-dired-buffers)
  (when (fboundp 'my/modeline-refresh-icons)
    (my/modeline-refresh-icons frame))
  (when (fboundp 'rytu/dashboard-configure-icons)
    (rytu/dashboard-configure-icons frame))
  (force-mode-line-update t))

(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :custom
  (nerd-icons-completion-icon-size 0.95)
  :config
  (add-hook 'marginalia-mode-hook #'my/icons--configure-completion)
  (my/icons--configure-completion))

(use-package kind-icon
  :ensure t
  :after corfu
  :custom
  (kind-icon-blend-background nil)
  (kind-icon-default-face 'corfu-default)
  :config
  (my/icons--configure-corfu))

(use-package nerd-icons-corfu
  :ensure t
  :after (corfu kind-icon)
  :config
  (my/icons--configure-corfu))

(use-package nerd-icons-dired
  :ensure t
  :commands nerd-icons-dired-mode
  :custom
  (nerd-icons-dired-icon-size 0.95)
  :hook
  (dired-mode . my/icons-dired-maybe-enable))

(my/refresh-icons)
(add-hook 'after-make-frame-functions #'my/refresh-icons)

(provide 'init-icons)
;;; init-icons.el ends here
