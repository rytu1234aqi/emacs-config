;;; init-unity.el --- Unity project integration -*- lexical-binding: t; -*-

;;; Commentary:
;; Project discovery, editor launching, logs, test/build commands, and a
;; compact command menu for Unity projects.  This module deliberately avoids
;; depending on a Git repository so Plastic SCM projects work with project.el.

;;; Code:

(require 'autorevert)
(require 'cl-lib)
(require 'compile)
(require 'json)
(require 'project)
(require 'server)
(require 'subr-x)

(defgroup my/unity nil
  "Unity integration for this Emacs configuration."
  :group 'tools
  :prefix "my/unity-")

(defcustom my/unity-editor-install-roots nil
  "Additional directories containing versioned Unity editor installations.

Each directory is expected to contain VERSION/Editor/Unity.exe.  Unity Hub's
secondary install directory and the standard Windows locations are searched
automatically."
  :type '(repeat directory)
  :group 'my/unity)

(defcustom my/unity-solution-overrides nil
  "Per-project Unity solution choices.

Entries are saved by `my/unity-select-solution'."
  :type '(alist :key-type directory :value-type file)
  :group 'my/unity)

(defcustom my/unity-last-build-method "BuildScript.PerformBuild"
  "Last static Unity build method passed to -executeMethod."
  :type 'string
  :group 'my/unity)

(defconst my/unity-project-directories
  '("Assets" "Packages" "ProjectSettings")
  "Directories that identify the root of a Unity project.")

(defconst my/unity-project-ignored-directories
  '("Library/" "Temp/" "Logs/" "Obj/" "Build/" "Builds/"
    "UserSettings/" ".vs/" ".idea/")
  "Generated Unity directories ignored by project.el and search commands.")

(defun my/unity-project-p (directory)
  "Return non-nil when DIRECTORY looks like a Unity project root."
  (and directory
       (cl-every (lambda (name)
                   (file-directory-p (expand-file-name name directory)))
                 my/unity-project-directories)))

(defun my/unity-find-root (&optional directory)
  "Find a Unity project root above DIRECTORY or `default-directory'."
  (let* ((start (expand-file-name (or directory default-directory)))
         (start (if (file-directory-p start)
                    start
                  (file-name-directory start))))
    (when start
      (when-let ((root (locate-dominating-file start #'my/unity-project-p)))
        (file-name-as-directory (expand-file-name root))))))

(defun my/project-try-unity (directory)
  "Return a project.el Unity project rooted above DIRECTORY."
  (when-let ((root (my/unity-find-root directory)))
    (cons 'unity root)))

(cl-defmethod project-root ((project (head unity)))
  "Return the root of Unity PROJECT."
  (cdr project))

(cl-defmethod project-name ((project (head unity)))
  "Return a readable name for Unity PROJECT."
  (file-name-nondirectory (directory-file-name (project-root project))))

(cl-defmethod project-ignores ((_project (head unity)) _directory)
  "Return generated directories ignored in a Unity project."
  my/unity-project-ignored-directories)

;; Let VC projects retain their native backend; this acts as the fallback for
;; Plastic SCM and otherwise unversioned Unity trees.
(add-hook 'project-find-functions #'my/project-try-unity t)

(defun my/unity-current-root (&optional noerror)
  "Return the current Unity root.

When NOERROR is nil, signal a user error outside a Unity project."
  (or (my/unity-find-root)
      (unless noerror
        (user-error "This buffer is not inside a Unity project"))))

(defun my/unity--solutions (root)
  "Return top-level solution files for Unity project ROOT."
  (let ((case-fold-search t))
    (sort (cl-remove-if-not
           #'file-regular-p
           (directory-files root t "[.]slnx?\\'" t))
          #'string-lessp)))

(defun my/unity-project-solution (&optional root)
  "Return the preferred solution for Unity project ROOT.

An explicit choice wins, followed by the sole solution, a solution named after
the project directory, and finally the first solution in lexical order."
  (when-let ((root (or root (my/unity-current-root t))))
    (setq root (file-name-as-directory (expand-file-name root)))
    (when-let ((solutions (my/unity--solutions root)))
      (let* ((override (alist-get root my/unity-solution-overrides
                                  nil nil #'string-equal))
             (project-name
              (file-name-nondirectory (directory-file-name root)))
             (matching
              (cl-find-if
               (lambda (file)
                 (string-equal (downcase (file-name-base file))
                               (downcase project-name)))
               solutions)))
        (cond
         ((and override (file-regular-p override)) override)
         ((= (length solutions) 1) (car solutions))
         (matching matching)
         (t (car solutions)))))))

(defun my/unity-select-solution ()
  "Choose and remember the solution used for the current Unity project."
  (interactive)
  (let* ((root (my/unity-current-root))
         (solutions (my/unity--solutions root)))
    (unless solutions
      (user-error "No .sln or .slnx exists at %s; regenerate project files in Unity" root))
    (let* ((table (mapcar (lambda (file)
                            (cons (file-name-nondirectory file) file))
                          solutions))
           (choice (completing-read "Unity solution: " table nil t nil nil
                                    (file-name-nondirectory
                                     (or (my/unity-project-solution root)
                                         (car solutions)))))
           (solution (cdr (assoc choice table))))
      (setf (alist-get root my/unity-solution-overrides nil nil #'string-equal)
            solution)
      (customize-save-variable 'my/unity-solution-overrides
                               my/unity-solution-overrides)
      (message "Unity solution: %s" solution)
      (when (fboundp 'my/csharp-restart-workspace)
        (my/csharp-restart-workspace))
      solution)))

(defun my/unity-project-version (&optional root)
  "Read the Unity editor version required by project ROOT."
  (let* ((root (or root (my/unity-current-root)))
         (version-file
          (expand-file-name "ProjectSettings/ProjectVersion.txt" root)))
    (unless (file-readable-p version-file)
      (user-error "Missing Unity version file: %s" version-file))
    (with-temp-buffer
      (insert-file-contents version-file)
      (goto-char (point-min))
      (if (re-search-forward "^m_EditorVersion:[[:space:]]*\\(.+\\)$" nil t)
          (string-trim (match-string 1))
        (user-error "Cannot read m_EditorVersion from %s" version-file)))))

(defun my/unity--hub-secondary-root ()
  "Return Unity Hub's configured secondary install directory, if any."
  (when-let* ((appdata (getenv "APPDATA"))
              (file (expand-file-name
                     "UnityHub/secondaryInstallPath.json" appdata))
              ((file-readable-p file)))
    (condition-case nil
        (let ((value (json-read-file file)))
          (and (stringp value) (not (string-empty-p value)) value))
      (error nil))))

(defun my/unity--editor-roots ()
  "Return existing Unity editor installation roots."
  (delete-dups
   (cl-remove-if-not
    #'file-directory-p
    (append my/unity-editor-install-roots
            (list (my/unity--hub-secondary-root)
                  "C:/Program Files/Unity/Hub/Editor"
                  "C:/Program Files/Unity/Editor"
                  "D:/Unity Editor")))))

(defun my/unity-editor-executable (&optional root)
  "Return the Unity executable matching project ROOT's required version."
  (let ((explicit (getenv "UNITY_EDITOR")))
    (or (and explicit (file-regular-p explicit) explicit)
        (let* ((root (or root (my/unity-current-root)))
               (version (my/unity-project-version root))
               (candidates
                (cl-mapcan
                 (lambda (base)
                   (list (expand-file-name
                          (format "%s/Editor/Unity.exe" version) base)
                         (expand-file-name "Editor/Unity.exe" base)
                         (expand-file-name "Unity.exe" base)))
                 (my/unity--editor-roots))))
          (or (cl-find-if #'file-regular-p candidates)
              (user-error
               "Unity %s was not found; customize my/unity-editor-install-roots"
               version))))))

(defun my/unity-open-project ()
  "Open the current project with its matching Unity editor."
  (interactive)
  (let* ((root (my/unity-current-root))
         (editor (my/unity-editor-executable root))
         (process (make-process
                   :name (format "Unity: %s"
                                 (file-name-nondirectory
                                  (directory-file-name root)))
                   :buffer (get-buffer-create "*Unity*")
                   :command (list editor "-projectPath" root)
                   :noquery t)))
    (set-process-query-on-exit-flag process nil)
    (message "Opening %s with %s" root editor)))

(defun my/unity-editor-log-file ()
  "Return the platform-specific Unity Editor log path."
  (if-let ((localappdata (getenv "LOCALAPPDATA")))
      (expand-file-name "Unity/Editor/Editor.log" localappdata)
    (expand-file-name "~/Library/Logs/Unity/Editor.log")))

(defun my/unity-open-editor-log ()
  "Open the Unity Editor log and follow new output."
  (interactive)
  (let ((file (my/unity-editor-log-file)))
    (unless (file-readable-p file)
      (user-error "Unity Editor log does not exist yet: %s" file))
    (find-file-other-window file)
    (read-only-mode 1)
    (auto-revert-tail-mode 1)
    (goto-char (point-max))))

(defun my/unity--shell-command (&rest arguments)
  "Quote ARGUMENTS and return a shell command string."
  (mapconcat #'shell-quote-argument arguments " "))

(defun my/unity--results-directory ()
  "Return and create the local Unity test-results directory."
  (let ((directory
         (expand-file-name "var/unity-test-results" user-emacs-directory)))
    (make-directory directory t)
    directory))

(defun my/unity-run-tests (platform)
  "Run Unity tests for PLATFORM in a compilation buffer.

PLATFORM is `EditMode', `PlayMode', or `All'.  Unity normally refuses a second
batch process while the same project is already open, so close that editor
instance before using this command."
  (interactive
   (list (completing-read "Test platform: "
                          '("EditMode" "PlayMode" "All") nil t nil nil
                          "EditMode")))
  (let* ((root (my/unity-current-root))
         (editor (my/unity-editor-executable root))
         (project-name
          (file-name-nondirectory (directory-file-name root)))
         (result-file
          (expand-file-name
           (format "%s-%s-%s.xml"
                   project-name (downcase platform)
                   (format-time-string "%Y%m%d-%H%M%S"))
           (my/unity--results-directory)))
         (arguments
          (append (list editor "-batchmode" "-projectPath" root "-runTests")
                  (unless (string-equal platform "All")
                    (list "-testPlatform" platform))
                  (list "-testResults" result-file "-logFile" "-")))
         (default-directory root))
    (message "Unity test results will be written to %s" result-file)
    (compilation-start
     (apply #'my/unity--shell-command arguments)
     'compilation-mode
     (lambda (_mode) (format "*Unity Tests: %s*" project-name)))))

(defun my/unity-run-build (method)
  "Run Unity static build METHOD through -executeMethod."
  (interactive
   (list (read-string "Static Unity build method: "
                      my/unity-last-build-method)))
  (when (string-empty-p method)
    (user-error "A fully qualified static build method is required"))
  (setq my/unity-last-build-method method)
  (let* ((root (my/unity-current-root))
         (editor (my/unity-editor-executable root))
         (project-name
          (file-name-nondirectory (directory-file-name root)))
         (default-directory root))
    (compilation-start
     (my/unity--shell-command
      editor "-batchmode" "-quit" "-projectPath" root
      "-executeMethod" method "-logFile" "-")
     'compilation-mode
     (lambda (_mode) (format "*Unity Build: %s*" project-name)))))

(defun my/unity-reload-solution ()
  "Restart the active C# workspace so generated Unity files are reloaded."
  (interactive)
  (cond
   ((fboundp 'my/csharp-restart-workspace)
    (my/csharp-restart-workspace))
   ((and (bound-and-true-p lsp-mode)
         (fboundp 'lsp-workspace-restart))
    (lsp-workspace-restart))
   (t
    (message "No active C# LSP workspace; opening a C# file will start one"))))

(defun my/unity-open-scripting-docs ()
  "Open the Unity scripting API documentation."
  (interactive)
  (browse-url "https://docs.unity3d.com/ScriptReference/"))

(defun my/unity--emacsclient-program ()
  "Return the preferred GUI emacsclient executable."
  (or (executable-find "emacsclientw.exe")
      (executable-find "emacsclientw")
      (executable-find "emacsclient.exe")
      (let ((candidate (expand-file-name "emacsclientw.exe"
                                         invocation-directory)))
        (and (file-regular-p candidate) candidate))
      "emacsclientw.exe"))

(defun my/unity-external-editor-settings ()
  "Show and copy the Unity External Tools settings for Emacs."
  (interactive)
  (let* ((program (my/unity--emacsclient-program))
         (arguments "--no-wait +$(Line) \"$(File)\"")
         (settings (format "External Script Editor: %s\nArguments: %s"
                           program arguments)))
    (kill-new settings)
    (message "%s (copied)" settings)))

(defun my/unity-status ()
  "Display a compact diagnostic report for the current Unity project."
  (interactive)
  (let* ((root (my/unity-current-root))
         (version (ignore-errors (my/unity-project-version root)))
         (editor (ignore-errors (my/unity-editor-executable root)))
         (solution (my/unity-project-solution root)))
    (with-help-window "*Unity Status*"
      (princ (format "Project:  %s\n" root))
      (princ (format "Version:  %s\n" (or version "not found")))
      (princ (format "Editor:   %s\n" (or editor "not found")))
      (princ (format "Solution: %s\n" (or solution "not generated")))
      (princ (format "Backend:  %s\n"
                     (if (fboundp 'my/csharp-current-backend)
                         (my/csharp-current-backend root)
                       "C# module not loaded")))
      (princ (format "csharp-ls: %s\n"
                     (or (executable-find "csharp-ls") "not found")))
      (princ (format "Tree-sitter C#: %s\n"
                     (if (and (fboundp 'my/treesit-ok-p)
                              (my/treesit-ok-p 'c-sharp))
                         "ready"
                       "unavailable"))))))

;; Unity invokes emacsclient, so make a server available once initialization is
;; complete.  A stale or incorrectly owned server directory must not prevent the
;; rest of init.el (including the dashboard) from loading.
(defvar my/unity-server-error nil
  "Most recent error reported while starting the Emacs server.")

(defun my/unity-ensure-server ()
  "Start the Emacs server without allowing a failure to abort startup."
  (unless noninteractive
    (condition-case err
        (progn
          (setq my/unity-server-error nil)
          (unless (server-running-p)
            (server-start)))
      (error
       (setq my/unity-server-error (error-message-string err))
       (message "Unity emacsclient integration unavailable; continuing: %s"
                my/unity-server-error)
       nil))))

(add-hook 'emacs-startup-hook #'my/unity-ensure-server)

(require 'transient)

(transient-define-prefix my/unity-menu ()
  "Unity project commands."
  [["Project"
    ("o" "Open in Unity" my/unity-open-project)
    ("l" "Follow Editor.log" my/unity-open-editor-log)
    ("s" "Choose solution" my/unity-select-solution)
    ("r" "Reload LSP solution" my/unity-reload-solution)]
   ["Automation"
    ("t" "Run tests" my/unity-run-tests)
    ("b" "Run build method" my/unity-run-build)]
   ["Setup / help"
    ("e" "External editor settings" my/unity-external-editor-settings)
    ("d" "Unity scripting docs" my/unity-open-scripting-docs)
    ("i" "Install Unity debugger" my/unity-debug-setup)
    ("a" "Attach debugger" my/unity-debug-attach)
    ("?" "Unity status" my/unity-status)]])

(global-set-key (kbd "C-c u") #'my/unity-menu)

(provide 'init-unity)
;;; init-unity.el ends here
