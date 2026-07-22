;;; init-icons-test.el --- Tests for shared icon integrations -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'init-icons)
(require 'corfu)
(require 'kind-icon)
(require 'nerd-icons-corfu)

(ert-deftest my/icons-require-a-graphical-frame-and-font ()
  (cl-letf (((symbol-function 'display-graphic-p)
             (lambda (&optional _frame) t))
            ((symbol-function 'find-font)
             (lambda (&rest _) 'font-object)))
    (should (my/icons-available-p (selected-frame))))
  (cl-letf (((symbol-function 'display-graphic-p)
             (lambda (&optional _frame) t))
            ((symbol-function 'find-font) (lambda (&rest _) nil)))
    (should-not (my/icons-available-p (selected-frame)))))

(ert-deftest my/icons-use-nerd-icons-for-corfu-when-available ()
  (let ((original (default-value 'corfu-margin-formatters)))
    (unwind-protect
        (progn
          (set-default 'corfu-margin-formatters '(another-formatter))
          (cl-letf (((symbol-function 'my/icons-available-p)
                     (lambda (&optional _frame) t)))
            (my/icons--configure-corfu (selected-frame)))
          (should (eq (car (default-value 'corfu-margin-formatters))
                      #'nerd-icons-corfu-formatter))
          (should (memq 'another-formatter
                        (default-value 'corfu-margin-formatters))))
      (set-default 'corfu-margin-formatters original))))

(ert-deftest my/icons-keep-kind-icon-as-a-fontless-corfu-fallback ()
  (let ((original (default-value 'corfu-margin-formatters)))
    (unwind-protect
        (progn
          (set-default 'corfu-margin-formatters
                       '(nerd-icons-corfu-formatter))
          (cl-letf (((symbol-function 'my/icons-available-p)
                     (lambda (&optional _frame) nil)))
            (my/icons--configure-corfu (selected-frame)))
          (should (equal (default-value 'corfu-margin-formatters)
                         '(kind-icon-margin-formatter))))
      (set-default 'corfu-margin-formatters original))))

(ert-deftest my/icons-integration-packages-are-installed ()
  (dolist (library '(nerd-icons-completion nerd-icons-corfu nerd-icons-dired))
    (should (locate-library (symbol-name library)))))

(provide 'init-icons-test)
;;; init-icons-test.el ends here
