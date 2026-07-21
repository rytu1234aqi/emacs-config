;;; init-modeline-test.el --- Tests for the global status line -*- lexical-binding: t; -*-

(require 'ert)
(require 'init-modeline)

(ert-deftest my/modeline-is-enabled-globally ()
  (should doom-modeline-mode)
  (should (equal (default-value 'mode-line-format)
                 (list "%e" (doom-modeline 'main)))))

(ert-deftest my/modeline-shows-editor-and-project-context ()
  (should (= doom-modeline-height 28))
  (should (= doom-modeline-bar-width 3))
  (should (eq doom-modeline-project-detection 'project))
  (should (eq doom-modeline-buffer-file-name-style 'relative-to-project))
  (should (equal doom-modeline-position-column-line-format
                 '("Ln %l, Col %c")))
  (should-not doom-modeline-column-zero-based)
  (should doom-modeline-buffer-encoding)
  (should doom-modeline-indent-info))

(ert-deftest my/modeline-keeps-language-status-without-font-icons ()
  (should doom-modeline-lsp)
  (should (eq doom-modeline-check 'simple))
  (should doom-modeline-project-name)
  (should-not doom-modeline-icon)
  (should-not doom-modeline-minor-modes)
  (should-not doom-modeline-env-version)
  (should-not doom-modeline-time))

(provide 'init-modeline-test)
;;; init-modeline-test.el ends here
