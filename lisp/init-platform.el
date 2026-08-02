;;; init-platform.el --- Cross-platform environment helpers -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep shared configuration portable while allowing each machine to add its
;; own executable directories through an untracked local.el.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defgroup my/platform nil
  "Cross-platform environment configuration."
  :group 'environment
  :prefix "my/platform-")

(defcustom my/platform-extra-exec-paths nil
  "Machine-specific directories prepended to PATH and `exec-path'.

Set this in local.el when a tool is installed outside a standard location."
  :type '(repeat directory)
  :group 'my/platform)

(defcustom my/platform-local-config-file
  (expand-file-name "local.el" user-emacs-directory)
  "Untracked file containing machine-specific configuration."
  :type 'file
  :group 'my/platform)

(defun my/platform-default-exec-paths ()
  "Return likely executable directories for the current platform."
  (let ((java-home (getenv "JAVA_HOME"))
        (dotnet-root (getenv "DOTNET_ROOT"))
        (user-profile (or (getenv "USERPROFILE") (getenv "HOME")))
        (local-appdata (getenv "LOCALAPPDATA"))
        (program-data (getenv "PROGRAMDATA")))
    (delq
     nil
     (append
      (when (eq system-type 'darwin)
        '("/opt/homebrew/bin" "/opt/homebrew/sbin"
          "/usr/local/bin" "/opt/local/bin"))
      (when (eq system-type 'windows-nt)
        (list "C:/Program Files/LLVM/bin"
              "C:/Program Files/CMake/bin"
              "C:/Program Files/Git/cmd"
              (and user-profile
                   (expand-file-name ".dotnet/tools" user-profile))
              (and user-profile
                   (expand-file-name "scoop/shims" user-profile))
              (and local-appdata
                   (expand-file-name "Microsoft/WindowsApps" local-appdata))
              (and program-data
                   (expand-file-name "chocolatey/bin" program-data))))
      (list (and java-home (expand-file-name "bin" java-home))
            (and dotnet-root (expand-file-name dotnet-root)))))))

(defun my/platform--path-components ()
  "Return the current PATH as a list of non-empty directories."
  (split-string (or (getenv "PATH") "")
                (regexp-quote
                 (if (characterp path-separator)
                     (char-to-string path-separator)
                   path-separator))
                t))

(defun my/platform-refresh-environment ()
  "Prepend existing configured tool directories to PATH and `exec-path'."
  (interactive)
  (let* ((configured (append my/platform-extra-exec-paths
                             (my/platform-default-exec-paths)))
         (directories
          (delete-dups
           (cl-loop for directory in configured
                    when (and directory (file-directory-p directory))
                    collect (directory-file-name
                             (expand-file-name directory)))))
         (separator (if (characterp path-separator)
                        (char-to-string path-separator)
                      path-separator)))
    (setq exec-path (delete-dups (append directories exec-path)))
    (setenv "PATH"
            (mapconcat #'identity
                       (delete-dups
                        (append directories
                                (my/platform--path-components)))
                       separator))
    directories))

(defun my/platform-first-executable (candidates &optional explicit)
  "Return the first executable in CANDIDATES, preferring EXPLICIT.

EXPLICIT may be either an executable name or an absolute path."
  (or (and explicit
           (or (executable-find explicit)
               (and (file-regular-p explicit)
                    (file-executable-p explicit)
                    (expand-file-name explicit))))
      (cl-loop for program in candidates
               for executable = (executable-find program)
               when executable return executable)))

(defun my/platform-load-local-config ()
  "Load `my/platform-local-config-file' when it exists."
  (interactive)
  (when (file-readable-p my/platform-local-config-file)
    (load my/platform-local-config-file nil 'nomessage)))

(provide 'init-platform)
;;; init-platform.el ends here
