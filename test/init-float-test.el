;;; init-float-test.el --- Tests for lightweight floating UI -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'init-float)

(ert-deftest my/floating-ui-loads-the-focused-popup-stack ()
  (dolist (library '(posframe vertico-posframe flymake-popon))
    (should (locate-library (symbol-name library)))
    (should (featurep library)))
  (should my/ui-floating-popups)
  (should vertico-posframe-mode)
  (should (eq vertico-posframe-poshandler
              #'my/vertico-posframe-poshandler))
  (should (= vertico-posframe-width 90))
  (should (= vertico-posframe-border-width 1))
  (should (eq flymake-popon-method 'posframe))
  (should (= flymake-popon-delay 0.45))
  (should (= flymake-popon-posframe-border-width 1))
  (should-not (assq 'flymake-popon-mode minor-mode-alist))
  (should (eq (lookup-key global-map (kbd "<f7>"))
              #'my/toggle-floating-ui)))

(ert-deftest my/floating-ui-detects-child-frame-support ()
  (let ((my/ui-floating-popups t))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'posframe-workable-p)
               (lambda () t)))
      (should (my/floating-ui-workable-p))))
  (let ((my/ui-floating-popups nil))
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'posframe-workable-p)
               (lambda () t)))
      (should-not (my/floating-ui-workable-p)))))

(ert-deftest my/vertico-posframe-uses-command-palette-placement ()
  (should
   (equal (my/vertico-posframe-poshandler
           '(:parent-frame-width 1000
             :parent-frame-height 800
             :posframe-width 400))
          '(300 . 96))))

(ert-deftest my/floating-ui-replaces-only-flymake-eldoc-in-code ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (setq-local flymake-mode t)
    (setq-local eldoc-documentation-functions
                '(flymake-eldoc-function keep-signatures))
    (let ((my/ui-floating-popups t)
          mode-argument)
      (cl-letf (((symbol-function 'flymake-popon-mode)
                 (lambda (argument) (setq mode-argument argument))))
        (my/floating-ui-configure-flymake))
      (should (= mode-argument 1))
      (should-not (memq #'flymake-eldoc-function
                        eldoc-documentation-functions))
      (should (memq 'keep-signatures eldoc-documentation-functions)))))

(ert-deftest my/floating-ui-restores-flymake-eldoc-when-disabled ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (setq-local flymake-mode t)
    (setq-local flymake-popon-mode t)
    (setq-local eldoc-documentation-functions '(keep-signatures))
    (let ((my/ui-floating-popups nil)
          mode-argument)
      (cl-letf (((symbol-function 'flymake-popon-mode)
                 (lambda (argument) (setq mode-argument argument))))
        (my/floating-ui-configure-flymake))
      (should (= mode-argument -1))
      (should (memq #'flymake-eldoc-function
                    eldoc-documentation-functions))
      (should (memq 'keep-signatures eldoc-documentation-functions)))))

(provide 'init-float-test)
;;; init-float-test.el ends here
