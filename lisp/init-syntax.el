;;; init-syntax.el --- Tree-sitter and lightweight diagnostics -*- lexical-binding: t; -*-

;; Emacs 30 embeds Tree-sitter ABI 13/14.  Grammar default branches now often
;; generate ABI 15, so every managed grammar is pinned to a verified release.

(require 'cl-lib)
(require 'eldoc)
(require 'flymake)
(require 'fringe)
(require 'subr-x)
(require 'treesit)

(defgroup my/syntax nil
  "Tree-sitter syntax highlighting and lightweight diagnostics."
  :group 'languages)

(defconst my/treesit-managed-languages
  '(bash c cpp css go html java javascript json python rust toml
         tsx typescript yaml c-sharp)
  "Tree-sitter languages managed by this configuration.")

(defconst my/treesit-mode-remaps
  '((c-mode      c-ts-mode        c)
    (csharp-mode csharp-ts-mode   c-sharp)
    (c++-mode    c++-ts-mode      cpp)
    (sh-mode     bash-ts-mode     bash)
    (css-mode    css-ts-mode      css)
    (js-mode     js-ts-mode       javascript)
    (json-mode   json-ts-mode     json)
    (python-mode python-ts-mode   python)
    (go-mode     go-ts-mode       go)
    (java-mode   java-ts-mode     java)
    (rust-mode   rust-ts-mode     rust)
    (yaml-mode   yaml-ts-mode     yaml))
  "Classic modes remapped when their compatible grammar is available.")

(setq treesit-language-source-alist
      '((bash       "https://github.com/tree-sitter/tree-sitter-bash" "v0.23.3")
        (c          "https://github.com/tree-sitter/tree-sitter-c" "v0.23.6")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp" "v0.23.4")
        (css        "https://github.com/tree-sitter/tree-sitter-css" "v0.23.2")
        (go         "https://github.com/tree-sitter/tree-sitter-go" "v0.23.4")
        (html       "https://github.com/tree-sitter/tree-sitter-html" "v0.23.2")
        (java       "https://github.com/tree-sitter/tree-sitter-java" "v0.23.5")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1")
        (json       "https://github.com/tree-sitter/tree-sitter-json" "v0.24.8")
        (python     "https://github.com/tree-sitter/tree-sitter-python" "v0.23.6")
        (rust       "https://github.com/tree-sitter/tree-sitter-rust" "v0.23.3")
        (toml       "https://github.com/tree-sitter/tree-sitter-toml" "v0.5.1")
        (tsx        "https://github.com/tree-sitter/tree-sitter-typescript"
                    "v0.23.2" "tsx/src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript"
                    "v0.23.2" "typescript/src")
        (yaml       "https://github.com/ikatyang/tree-sitter-yaml" "v0.5.0")
        (c-sharp    "https://github.com/tree-sitter/tree-sitter-c-sharp"
                    "v0.23.1")))

(setq-default treesit-font-lock-level 4)

(defun my/treesit-ok-p (language)
  "Return non-nil when LANGUAGE has a loadable Tree-sitter grammar."
  (and (treesit-available-p)
       (treesit-language-available-p language)))

(defun my/treesit-language-status (language)
  "Return detailed availability information for LANGUAGE."
  (if (treesit-available-p)
      (treesit-language-available-p language t)
    '(nil treesit-unavailable)))

(defun my/treesit--status-label (status)
  "Return a readable label for detailed Tree-sitter STATUS."
  (cond
   ((eq status t) "ready")
   ((consp status)
    (mapconcat (lambda (item) (format "%s" item)) (cdr status) " "))
   (t "unavailable")))

(defun my/treesit-install-grammars ()
  "Install missing or ABI-incompatible managed Tree-sitter grammars."
  (interactive)
  (unless (treesit-available-p)
    (user-error "This Emacs was built without Tree-sitter support"))
  (let (failures
        (installed 0))
    (dolist (language my/treesit-managed-languages)
      (unless (my/treesit-ok-p language)
        (message "Installing compatible Tree-sitter grammar for %s..." language)
        (condition-case err
            (progn
              (treesit-install-language-grammar language)
              (cl-incf installed))
          (error
           (push (cons language (error-message-string err)) failures)))))
    (if failures
        (display-warning
         'my/treesit
         (mapconcat (lambda (failure)
                      (format "%s: %s" (car failure) (cdr failure)))
                    (nreverse failures) "\n")
         :warning)
      (if (> installed 0)
          ;; A loaded DLL is cached for the lifetime of an Emacs process,
          ;; particularly on Windows.  A fresh process sees the replacement.
          (message "Installed %d grammars; restart Emacs to reload their DLLs"
                   installed)
        (message "All managed Tree-sitter grammars are ready")))))

(defun my/treesit-doctor ()
  "Display ABI and availability for every managed grammar."
  (interactive)
  (with-help-window "*Tree-sitter Doctor*"
    (if (treesit-available-p)
        (princ (format "Runtime ABI: %s–%s\nFont-lock:  level %s\n\n"
                       (treesit-library-abi-version t)
                       (treesit-library-abi-version)
                       treesit-font-lock-level))
      (princ "Runtime:     unavailable in this Emacs build\n\n"))
    (dolist (language my/treesit-managed-languages)
      (princ (format "%-12s %s\n"
                     language
                     (my/treesit--status-label
                      (my/treesit-language-status language)))))))

(when (treesit-available-p)
  (dolist (spec my/treesit-mode-remaps)
    (pcase-let ((`(,from ,to ,language) spec))
      (when (and (fboundp to) (my/treesit-ok-p language))
        (setf (alist-get from major-mode-remap-alist) to))))

  (dolist (spec '(("\\.ts\\'" typescript-ts-mode typescript)
                  ("\\.tsx\\'" tsx-ts-mode tsx)
                  ("\\.toml\\'" toml-ts-mode toml)))
    (pcase-let ((`(,pattern ,mode ,language) spec))
      (when (and (fboundp mode) (my/treesit-ok-p language))
        (add-to-list 'auto-mode-alist (cons pattern mode))))))

(defvar-local my/csharp-treesit-member-highlighting-enabled nil
  "Whether extra C# member highlighting has been installed in this buffer.")

(defun my/csharp-treesit-enable-member-highlighting ()
  "Highlight C# member access as a property unless a stronger rule applies."
  (when (and (derived-mode-p 'csharp-ts-mode)
             (treesit-ready-p 'c-sharp)
             (not my/csharp-treesit-member-highlighting-enabled))
    ;; Append the weak property rule after the built-in function-call rules.
    ;; Calls such as obj.Run() keep their function face, while obj.Instance
    ;; gains the property-use face supplied by Doom Themes.
    (setq-local
     treesit-font-lock-settings
     (append treesit-font-lock-settings
             (treesit-font-lock-rules
              :language 'c-sharp
              :feature 'member
              '((member_access_expression
                 name: (identifier) @font-lock-property-use-face)))))
    (cl-pushnew 'member (nth 2 treesit-font-lock-feature-list))
    (setq my/csharp-treesit-member-highlighting-enabled t)
    (treesit-font-lock-recompute-features)))

(add-hook 'csharp-ts-mode-hook
          #'my/csharp-treesit-enable-member-highlighting)

;; Flymake is the single diagnostics frontend for Eglot and C# lsp-mode.
;; Do not render diagnostic prose at line ends; use theme-aware wave underlines,
;; a compact fringe marker, Eldoc at point, and an on-demand Consult list.
(setq flymake-no-changes-timeout 0.8
      flymake-show-diagnostics-at-end-of-line nil
      flymake-fringe-indicator-position 'right-fringe
      flymake-suppress-zero-counters t
      flymake-wrap-around t
      eldoc-idle-delay 0.35
      eldoc-echo-area-use-multiline-p nil
      eldoc-echo-area-display-truncation-message nil)

(when (fboundp 'define-fringe-bitmap)
  (define-fringe-bitmap 'my/flymake-error-bitmap
    [24 60 126 255 255 126 60 24] 8 8 'center)
  (define-fringe-bitmap 'my/flymake-warning-bitmap
    [24 24 60 60 126 126 255 0] 8 8 'center)
  (define-fringe-bitmap 'my/flymake-note-bitmap
    [0 60 126 126 126 126 60 0] 8 8 'center))

(setq flymake-error-bitmap '(my/flymake-error-bitmap compilation-error)
      flymake-warning-bitmap '(my/flymake-warning-bitmap compilation-warning)
      flymake-note-bitmap '(my/flymake-note-bitmap compilation-info))

(defun my/diagnostics-setup ()
  "Use Flymake as the sole lightweight diagnostics frontend."
  (when (fboundp 'flycheck-mode)
    (flycheck-mode -1))
  (flymake-mode 1))

(add-hook 'prog-mode-hook #'my/diagnostics-setup)

(defun my/flymake-show-diagnostic-at-point ()
  "Show diagnostics at point as one compact minibuffer message."
  (interactive)
  (if-let ((diagnostics (flymake-diagnostics (point))))
      (message "%s"
               (mapconcat #'flymake-diagnostic-oneliner diagnostics "  •  "))
    (message "No diagnostic at point")))

(defvar-keymap my/diagnostics-map
  :doc "Flymake navigation and diagnostic views."
  "n" #'flymake-goto-next-error
  "p" #'flymake-goto-prev-error
  "d" #'my/flymake-show-diagnostic-at-point
  "l" #'consult-flymake
  "b" #'flymake-show-buffer-diagnostics
  "P" #'flymake-show-project-diagnostics
  "s" #'flymake-start)

(global-set-key (kbd "C-c !") my/diagnostics-map)

(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements "C-c !" "diagnostics"))

(provide 'init-syntax)
;;; init-syntax.el ends here
