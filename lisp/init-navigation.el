;;; init-navigation.el --- Modern navigation and workspaces -*- lexical-binding: t; -*-

;; Keep navigation responsive in large Unity projects: the small completion
;; core loads once, context actions stay on demand, and workspaces use Emacs'
;; built-in tab-bar without background scanning or session restoration.

(require 'project)
(require 'subr-x)
(require 'use-package)
(require 'windmove)
(require 'winner)
(require 'xref)

(declare-function consult--customize-put "consult")

(setq enable-recursive-minibuffers t
      minibuffer-prompt-properties
      '(read-only t cursor-intangible t face minibuffer-prompt)
      read-extended-command-predicate
      #'command-completion-default-include-p
      completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t)
(add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)

(use-package which-key
  :custom
  (which-key-idle-delay 0.45)
  (which-key-idle-secondary-delay 0.05)
  :config
  (which-key-mode 1))

(use-package vertico
  :custom
  (vertico-count 12)
  (vertico-cycle t)
  (vertico-scroll-margin 2)
  :init
  (vertico-mode 1))

(use-package vertico-directory
  :ensure nil
  :after vertico
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

(use-package marginalia
  :after vertico
  :init
  (marginalia-mode 1))

(use-package consult
  :demand t
  :bind (("C-s"     . consult-line)
         ("C-x b"   . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x 5 b" . consult-buffer-other-frame)
         ("C-x p b" . consult-project-buffer)
         ("C-x r b" . consult-bookmark)
         ("C-c b"   . consult-buffer)
         ("C-c g"   . consult-grep)
         ("C-c r"   . consult-ripgrep)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-g e"   . consult-flymake)
         ("M-y"     . consult-yank-pop))
  :custom
  (consult-narrow-key "<")
  ;; Keep C-x b focused on buffers belonging to the current tab workspace.
  (consult-buffer-list-function #'consult--frame-buffer-list)
  (xref-show-xrefs-function #'consult-xref)
  (xref-show-definitions-function #'consult-xref)
  :config
  ;; File previews stay live, but rapid typing does not repeatedly open files.
  (consult-customize consult-find consult-grep consult-ripgrep
                     :preview-key '(:debounce 0.25 any)))

(use-package embark
  :ensure t
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package embark-consult
  :ensure t
  :after (embark consult))

(defgroup my/workspace nil
  "Lightweight project workspaces backed by the built-in tab bar."
  :group 'convenience)

(defun my/workspace--project-name (project)
  "Return a concise tab name for PROJECT."
  (or (ignore-errors (project-name project))
      (file-name-nondirectory
       (directory-file-name (project-root project)))))

(defun my/workspace--open-project (project)
  "Open PROJECT in a named tab and prompt for one of its files."
  (let* ((root (file-name-as-directory (project-root project)))
         (name (my/workspace--project-name project)))
    ;; `tab-bar-switch-to-tab' creates NAME when it does not exist and reuses it
    ;; otherwise, so repeated project switches do not create duplicate tabs.
    (tab-bar-switch-to-tab name)
    (let ((default-directory root))
      (call-interactively #'project-find-file))))

(defun my/workspace-open-project (directory)
  "Choose a project DIRECTORY and open it as a dedicated workspace."
  (interactive (list (project-prompt-project-dir)))
  (my/workspace--open-project (project-current t directory)))

(defun my/workspace-open-current-project ()
  "Open the current project as a dedicated workspace."
  (interactive)
  (my/workspace--open-project (project-current t)))

(defun my/workspace-new ()
  "Create a clean workspace and show the Dashboard when available."
  (interactive)
  (tab-bar-new-tab)
  (if (fboundp 'rytu/dashboard-open)
      (rytu/dashboard-open)
    (switch-to-buffer (get-buffer-create "*scratch*"))))

(use-package tab-bar
  :ensure nil
  :demand t
  :custom
  ;; One workspace needs no permanent strip; the tab bar appears at two tabs.
  (tab-bar-show 1)
  (tab-bar-close-button-show nil)
  (tab-bar-new-button-show nil)
  (tab-bar-separator " ")
  (tab-bar-format '(tab-bar-format-tabs tab-bar-separator))
  (tab-bar-tab-name-function #'tab-bar-tab-name-truncated)
  (tab-bar-tab-name-truncated-max 24)
  :config
  (tab-bar-mode 1)
  (tab-bar-history-mode 1)
  (set-face-attribute 'tab-bar nil :height 0.95 :box nil)
  (set-face-attribute 'tab-bar-tab nil
                      :weight 'semi-bold :box nil :underline nil)
  (set-face-attribute 'tab-bar-tab-inactive nil
                      :weight 'normal :box nil :underline nil))

(winner-mode 1)

(defvar-keymap my/workspace-map
  :doc "Commands for project tabs and window layouts."
  "n" #'my/workspace-new
  "x" #'tab-bar-close-tab
  "r" #'tab-bar-rename-tab
  "w" #'tab-bar-switch-to-tab
  "p" #'my/workspace-open-project
  "[" #'tab-bar-switch-to-prev-tab
  "]" #'tab-bar-switch-to-next-tab
  "u" #'tab-bar-undo-close-tab
  "z" #'winner-undo
  "Z" #'winner-redo
  "h" #'windmove-left
  "j" #'windmove-down
  "k" #'windmove-up
  "l" #'windmove-right
  "H" #'windmove-swap-states-left
  "J" #'windmove-swap-states-down
  "K" #'windmove-swap-states-up
  "L" #'windmove-swap-states-right
  "<left>" #'windmove-left
  "<down>" #'windmove-down
  "<up>" #'windmove-up
  "<right>" #'windmove-right
  "S-<left>" #'windmove-swap-states-left
  "S-<down>" #'windmove-swap-states-down
  "S-<up>" #'windmove-swap-states-up
  "S-<right>" #'windmove-swap-states-right)

(global-set-key (kbd "C-c w") my/workspace-map)
(add-to-list 'project-switch-commands
             '(my/workspace-open-current-project "Workspace" ?w) t)

(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements "C-c w" "workspace"))

(provide 'init-navigation)
;;; init-navigation.el ends here
