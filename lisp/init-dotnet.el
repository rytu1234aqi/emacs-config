;;; init-dotnet.el --- .NET CLI workflow -*- lexical-binding: t; -*-

;;; Commentary:
;; Small compilation-mode wrappers for ordinary SDK-style .NET projects.
;; Unity projects use their matching editor instead because generated csproj
;; files are not the authoritative Unity build graph.

;;; Code:

(require 'compile)
(require 'project)
(require 'subr-x)
(require 'init-unity)

(defun my/dotnet--project-marker-p (directory)
  "Return non-nil when DIRECTORY contains a .NET solution or project."
  (let ((case-fold-search t))
    (directory-files directory nil "[.]\\(?:slnx?\\|csproj\\|fsproj\\)\\'"
                     t 1)))

(defun my/dotnet-project-root ()
  "Return the root used for .NET CLI commands."
  (or (when-let ((project (project-current nil)))
        (project-root project))
      (locate-dominating-file default-directory #'my/dotnet--project-marker-p)
      (user-error "No project.el, .sln, .csproj, or .fsproj root was found")))

(defun my/dotnet--ensure-sdk-project ()
  "Reject Unity-generated projects for direct dotnet CLI operations."
  (when-let ((unity-root (my/unity-current-root t)))
    (user-error
     "This is a Unity project (%s); use C-c u for Unity tests/builds"
     unity-root)))

(defun my/dotnet--run (verb &optional arguments)
  "Run `dotnet VERB ARGUMENTS' from the current project root."
  (my/dotnet--ensure-sdk-project)
  (unless (executable-find "dotnet")
    (user-error "dotnet is not on PATH"))
  (let* ((root (file-name-as-directory (my/dotnet-project-root)))
         (default-directory root)
         (command (string-join
                   (delq nil
                         (list "dotnet" verb
                               (and arguments
                                    (not (string-empty-p arguments))
                                    arguments)))
                   " "))
         (name (file-name-nondirectory (directory-file-name root))))
    (compilation-start
     command 'compilation-mode
     (lambda (_mode) (format "*.NET %s: %s*" verb name)))))

(defun my/dotnet-restore (&optional arguments)
  "Run dotnet restore with optional ARGUMENTS.

With a prefix argument, prompt for command-line arguments."
  (interactive
   (list (when current-prefix-arg (read-string "dotnet restore arguments: "))))
  (my/dotnet--run "restore" arguments))

(defun my/dotnet-build (&optional arguments)
  "Run dotnet build with optional ARGUMENTS.

With a prefix argument, prompt for command-line arguments."
  (interactive
   (list (when current-prefix-arg (read-string "dotnet build arguments: "))))
  (my/dotnet--run "build" arguments))

(defun my/dotnet-test (&optional arguments)
  "Run dotnet test with optional ARGUMENTS.

With a prefix argument, prompt for command-line arguments."
  (interactive
   (list (when current-prefix-arg (read-string "dotnet test arguments: "))))
  (my/dotnet--run "test" arguments))

(defun my/dotnet-run (&optional arguments)
  "Run dotnet run with optional ARGUMENTS.

With a prefix argument, prompt for command-line arguments."
  (interactive
   (list (when current-prefix-arg (read-string "dotnet run arguments: "))))
  (my/dotnet--run "run" arguments))

(defvar my/dotnet-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "r") #'my/dotnet-restore)
    (define-key map (kbd "b") #'my/dotnet-build)
    (define-key map (kbd "t") #'my/dotnet-test)
    (define-key map (kbd "x") #'my/dotnet-run)
    (define-key map (kbd "i") #'my/dotnet-debug-setup)
    (define-key map (kbd "d") #'dap-debug)
    map)
  "Keymap for .NET CLI and debugger commands.")

(global-set-key (kbd "C-c n") my/dotnet-command-map)

(provide 'init-dotnet)
;;; init-dotnet.el ends here
