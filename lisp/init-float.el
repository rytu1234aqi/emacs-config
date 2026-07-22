;;; init-float.el --- Lightweight floating UI -*- lexical-binding: t; -*-

;;; 浮层只用于两类短暂信息：候选选择和光标处诊断。普通帮助、日志和
;;; Which-Key 继续使用原生窗口，避免创建过多子框架或依赖失维护扩展。

(require 'cl-lib)
(require 'flymake)
(require 'init-appearance)
(require 'use-package)
(require 'vertico)

(defcustom my/ui-floating-popups t
  "Use focused completion and diagnostic popups.

Graphical frames use child frames when supported.  Terminal frames keep the
normal Vertico minibuffer and use Flymake's text popup fallback."
  :type 'boolean
  :group 'my/ui)

(use-package posframe
  :ensure t
  :demand t)

(defun my/floating-ui-workable-p (&optional frame)
  "Return non-nil when child-frame popups work in FRAME."
  (let ((frame (or frame (selected-frame))))
    (and my/ui-floating-popups
         (display-graphic-p frame)
         (fboundp 'posframe-workable-p)
         (with-selected-frame frame
           (posframe-workable-p)))))

(defun my/vertico-posframe-poshandler (info)
  "Place a Vertico posframe near the top center using INFO.

The placement resembles a command palette and avoids covering the code around
point, unlike a frame-centered popup."
  (let ((parent-width (or (plist-get info :parent-frame-width) 0))
        (parent-height (or (plist-get info :parent-frame-height) 0))
        (posframe-width (or (plist-get info :posframe-width) 0)))
    (cons (max 0 (/ (- parent-width posframe-width) 2))
          (max 24 (round (* parent-height 0.12))))))

(use-package vertico-posframe
  :ensure t
  :demand t
  :after (posframe vertico)
  :custom
  (vertico-posframe-width 90)
  (vertico-posframe-min-width 58)
  (vertico-posframe-border-width 1)
  (vertico-posframe-truncate-lines t)
  (vertico-posframe-poshandler #'my/vertico-posframe-poshandler)
  (vertico-posframe-parameters
   '((left-fringe . 8)
     (right-fringe . 8)
     (internal-border-width . 8)))
  :config
  ;; The extension checks `posframe-workable-p' for each minibuffer.  Keeping
  ;; its global mode enabled therefore preserves ordinary Vertico on terminals.
  (vertico-posframe-mode (if my/ui-floating-popups 1 -1)))

(defun my/floating-ui--face-color (face attribute fallback)
  "Read FACE ATTRIBUTE, using FALLBACK for unspecified values."
  (let ((value (face-attribute face attribute nil t)))
    (if (or (not (stringp value))
            (string-prefix-p "unspecified" value))
        fallback
      value)))

(defun my/floating-ui-apply-faces (&optional _frame)
  "Apply theme-aware colors to all floating UI faces."
  (let* ((background
          (my/floating-ui--face-color
           'tooltip :background (face-background 'default nil t)))
         (foreground (face-foreground 'default nil t))
         (border
          (my/floating-ui--face-color 'shadow :foreground foreground)))
    (when (facep 'vertico-posframe)
      (set-face-attribute 'vertico-posframe nil
                          :inherit 'default
                          :background background
                          :foreground foreground))
    ;; Nested minibuffers should look like one coherent panel instead of using
    ;; the extension's default red/green/blue depth borders.
    (dolist (face '(vertico-posframe-border
                    vertico-posframe-border-2
                    vertico-posframe-border-3
                    vertico-posframe-border-4
                    vertico-posframe-border-fallback))
      (when (facep face)
        (set-face-attribute face nil :background border)))
    (when (facep 'flymake-popon)
      (set-face-attribute 'flymake-popon nil
                          :inherit 'default
                          :background background
                          :foreground foreground))
    (when (facep 'flymake-popon-posframe-border)
      (set-face-attribute 'flymake-popon-posframe-border nil
                          :foreground border))))

(defun my/floating-ui-configure-flymake ()
  "Show Flymake diagnostics near point without duplicating Eldoc text."
  (cond
   ((and my/ui-floating-popups
         flymake-mode
         (derived-mode-p 'prog-mode))
    (flymake-popon-mode 1)
    ;; Flymake normally also sends the same diagnostic to the echo area.  Keep
    ;; other Eldoc providers (signatures and documentation), removing only the
    ;; duplicate diagnostic provider in this buffer.
    (remove-hook 'eldoc-documentation-functions
                 #'flymake-eldoc-function t))
   (t
    (when (bound-and-true-p flymake-popon-mode)
      (flymake-popon-mode -1))
    (when (and flymake-mode (derived-mode-p 'prog-mode))
      (add-hook 'eldoc-documentation-functions
                #'flymake-eldoc-function nil t)))))

(use-package flymake-popon
  :ensure t
  :demand t
  :after (flymake posframe)
  :custom
  (flymake-popon-method 'posframe)
  (flymake-popon-delay 0.45)
  (flymake-popon-width 72)
  (flymake-popon-posframe-border-width 1)
  (flymake-popon-posframe-extra-arguments
   '(:poshandler posframe-poshandler-point-bottom-left-corner-upward
     :internal-border-width 7
     :left-fringe 4
     :right-fringe 4
     :lines-truncate nil
     :accept-focus nil))
  :config
  ;; Doom Modeline already reports Flymake state; an extra minor-mode label is
  ;; visual noise and can make the right side jump while changing buffers.
  (setq minor-mode-alist
        (assq-delete-all 'flymake-popon-mode minor-mode-alist))
  (add-hook 'flymake-mode-hook #'my/floating-ui-configure-flymake)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and flymake-mode (derived-mode-p 'prog-mode))
        (my/floating-ui-configure-flymake)))))

(defun my/floating-ui-refresh ()
  "Refresh popup modes, existing Flymake buffers and theme faces."
  (interactive)
  (when (fboundp 'flymake-popon--hide)
    (flymake-popon--hide))
  (when (and (boundp 'flymake-popon--timer)
             (timerp flymake-popon--timer))
    (cancel-timer flymake-popon--timer)
    (setq flymake-popon--timer nil))
  (vertico-posframe-mode (if my/ui-floating-popups 1 -1))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'prog-mode)
        (my/floating-ui-configure-flymake))))
  (when (fboundp 'posframe-delete-all)
    (posframe-delete-all))
  (my/floating-ui-apply-faces))

(defun my/toggle-floating-ui ()
  "Toggle completion and diagnostic popups."
  (interactive)
  (setq my/ui-floating-popups (not my/ui-floating-popups))
  (my/floating-ui-refresh)
  (message "Floating UI %s"
           (if my/ui-floating-popups "enabled" "disabled")))

(unless (advice-member-p #'my/floating-ui-apply-faces #'my/load-ui-theme)
  (advice-add #'my/load-ui-theme :after #'my/floating-ui-apply-faces))
(my/floating-ui-apply-faces)
(global-set-key (kbd "<f7>") #'my/toggle-floating-ui)

(provide 'init-float)
;;; init-float.el ends here
