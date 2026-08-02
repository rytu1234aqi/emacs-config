;;; init-debug.el --- DAP debugging for C/C++, C#, .NET, and Unity -*- lexical-binding: t; -*-

;;; Commentary:
;; dap-mode provides real source breakpoints, stepping, locals, watches, and a
;; debug console.  Adapter downloads stay explicit: use `my/cpp-debug-setup',
;; `my/unity-debug-setup', or `my/dotnet-debug-setup' once, rather than
;; downloading at every startup.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar dap-netcore-download-url)
(defvar dap-codelldb-debug-program)
(declare-function dap-netcore-update-debugger "dap-netcore")
(declare-function dap-unity-setup "dap-unity")
(declare-function dap-codelldb-setup "dap-codelldb")
(declare-function my/cpp-single-file-executable "init" (&optional file))
(declare-function my/project-root-or-current "init")
(defvar my/cpp-last-executable)

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

(defun my/cpp-debug-setup ()
  "Download and install the CodeLLDB adapter for C/C++ once.

dap-codelldb picks the release asset for the current platform by itself:
aarch64/x86_64-darwin on macOS, x86_64-windows on Windows."
  (interactive)
  (my/debug--require 'dap-codelldb)
  (unless (fboundp 'dap-codelldb-setup)
    (user-error "This dap-mode version has no codelldb installer"))
  (call-interactively #'dap-codelldb-setup))

(defun my/cpp--debug-executable-candidates ()
  "Return deduplicated C/C++ executables near the current buffer.
Order: cached build, source-name executable, platform default, then build/*."
  (let* ((file (buffer-file-name))
         (default-directory (my/project-root-or-current))
         (cached (cond
                  ((and (boundp 'my/cpp-last-executable)
                        (stringp my/cpp-last-executable))
                   my/cpp-last-executable)
                  ((and file (fboundp 'my/cpp-single-file-executable))
                   (my/cpp-single-file-executable file))))
         (source-exe
          (and file
               (concat (file-name-sans-extension file)
                       (if (eq system-type 'windows-nt) ".exe" ""))))
         (a-out (expand-file-name
                 (if (eq system-type 'windows-nt) "a.exe" "a.out")))
         (preferred (delq nil (list cached source-exe a-out)))
         (candidates
          (append
           (cl-remove-if-not
            (lambda (candidate)
              (and (file-regular-p candidate)
                   (file-executable-p candidate)))
            preferred)
           (cl-remove-if-not
            (lambda (candidate)
              (and (file-regular-p candidate)
                   (file-executable-p candidate)))
            (file-expand-wildcards "build/*" t)))))
    (delete-dups candidates)))

(defun my/cpp-debug ()
  "Debug the current C/C++ program through dap-mode and CodeLLDB.
Automatically finds the executable: single-file exe first, then project
build output.  Run `my/cpp-debug-setup' once before the first session."
  (interactive)
  (my/debug--require 'dap-codelldb)
  (unless (and (boundp 'dap-codelldb-debug-program)
               (stringp dap-codelldb-debug-program)
               (file-exists-p dap-codelldb-debug-program))
    (user-error "CodeLLDB adapter not installed; run M-x my/cpp-debug-setup first"))
  (let* ((candidates (my/cpp--debug-executable-candidates))
         (exe (cond ((null candidates) nil)
                    ((= (length candidates) 1) (car candidates))
                    (t (completing-read "Debug executable: " candidates nil t)))))
    (unless (and exe (not (string-empty-p exe)))
      (user-error "No executable found. Compile first with C-c r (single file) or C-c b (project)"))
    (dap-mode 1)
    (dap-debug (list :type "lldb"
                     :request "launch"
                     :name "C++ (codelldb)"
                     :program (expand-file-name exe)
                     :cwd (my/project-root-or-current)))))

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
  (require 'dap-unity nil t)
  ;; Registers the "lldb" provider only; the adapter binary is downloaded
  ;; explicitly via `my/cpp-debug-setup'.
  (require 'dap-codelldb nil t))

(defvar my/debug-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "d") #'dap-debug)
    (define-key map (kbd "a") #'my/unity-debug-attach)
    (define-key map (kbd "u") #'my/unity-debug-setup)
    (define-key map (kbd "N") #'my/dotnet-debug-setup)
    (define-key map (kbd "C") #'my/cpp-debug-setup)
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
