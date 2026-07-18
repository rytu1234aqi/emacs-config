;;; init-debug.el --- DAP debugging for C#, .NET, and Unity -*- lexical-binding: t; -*-

;;; Commentary:
;; dap-mode provides real source breakpoints, stepping, locals, watches, and a
;; debug console.  Adapter downloads stay explicit: use `my/unity-debug-setup'
;; or `my/dotnet-debug-setup' once, rather than downloading at every startup.

;;; Code:

(require 'subr-x)

(defvar dap-netcore-download-url)
(declare-function dap-netcore-update-debugger "dap-netcore")
(declare-function dap-unity-setup "dap-unity")

(defgroup my/debug nil
  "Debug adapter integration."
  :group 'tools
  :prefix "my/debug-")

(defcustom my/netcoredbg-windows-download-url
  "https://github.com/Samsung/netcoredbg/releases/download/3.2.0-1092/netcoredbg-win64.zip"
  "Pinned official win64 netcoredbg archive used on Windows.

dap-mode's HTML scraper can break when GitHub changes its release page.  An
explicit release asset makes first-time setup reproducible."
  :type 'string
  :group 'my/debug)

(defun my/debug--require (feature)
  "Load dap-mode adapter FEATURE or report a useful error."
  (require 'dap-mode)
  (unless (require feature nil t)
    (user-error "The installed dap-mode package does not provide %s" feature)))

(defun my/unity-debug-setup ()
  "Download and install dap-mode's Unity debug adapter once."
  (interactive)
  (my/debug--require 'dap-unity)
  (unless (fboundp 'dap-unity-setup)
    (user-error "This dap-mode version has no dap-unity-setup command"))
  (call-interactively #'dap-unity-setup))

(defun my/unity-debug-attach ()
  "Attach dap-mode to a running Unity Editor.

The Unity editor must have Editor Attaching enabled.  Run
`my/unity-debug-setup' once before the first session."
  (interactive)
  (my/debug--require 'dap-unity)
  (dap-mode 1)
  ;; dap-unity registers this built-in template.  Its `launch' request means
  ;; "select and attach to a Unity editor" in the Unity debug adapter.
  (dap-debug (list :type "unity"
                   :request "launch"
                   :name "Unity Editor")))

(defun my/dotnet-debug-setup ()
  "Download and install netcoredbg for ordinary .NET projects once."
  (interactive)
  (my/debug--require 'dap-netcore)
  (when (eq system-type 'windows-nt)
    (setq dap-netcore-download-url my/netcoredbg-windows-download-url))
  (unless (fboundp 'dap-netcore-update-debugger)
    (user-error "This dap-mode version has no netcoredbg installer"))
  (call-interactively #'dap-netcore-update-debugger))

(use-package dap-mode
  :commands (dap-mode
             dap-debug
             dap-breakpoint-toggle
             dap-breakpoint-delete-all
             dap-continue
             dap-next
             dap-step-in
             dap-step-out
             dap-disconnect
             dap-eval-thing-at-point
             dap-hydra)
  :init
  (setq dap-auto-configure-features
        '(sessions locals breakpoints expressions tooltip controls))
  :config
  (dap-auto-configure-mode 1)
  ;; Register templates when the adapters are shipped by dap-mode, but never
  ;; download their binaries implicitly during startup.
  (when (require 'dap-netcore nil t)
    (when (eq system-type 'windows-nt)
      (setq dap-netcore-download-url my/netcoredbg-windows-download-url)))
  (require 'dap-unity nil t))

(defvar my/debug-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "d") #'dap-debug)
    (define-key map (kbd "a") #'my/unity-debug-attach)
    (define-key map (kbd "u") #'my/unity-debug-setup)
    (define-key map (kbd "N") #'my/dotnet-debug-setup)
    (define-key map (kbd "b") #'dap-breakpoint-toggle)
    (define-key map (kbd "B") #'dap-breakpoint-delete-all)
    (define-key map (kbd "c") #'dap-continue)
    (define-key map (kbd "n") #'dap-next)
    (define-key map (kbd "i") #'dap-step-in)
    (define-key map (kbd "o") #'dap-step-out)
    (define-key map (kbd "e") #'dap-eval-thing-at-point)
    (define-key map (kbd "h") #'dap-hydra)
    (define-key map (kbd "q") #'dap-disconnect)
    map)
  "Keymap for Debug Adapter Protocol commands.")

(global-set-key (kbd "C-c d") my/debug-command-map)

(provide 'init-debug)
;;; init-debug.el ends here
