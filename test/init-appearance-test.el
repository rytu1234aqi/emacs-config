;;; init-appearance-test.el --- Tests for fonts and themes -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'init-appearance)

(ert-deftest my/ui-font-selection-respects-priority ()
  (cl-letf (((symbol-function 'font-family-list)
             (lambda (&optional _frame)
               '("Consolas" "JetBrains Mono" "Arial"))))
    (should (equal (my/ui--first-available-font
                    '("Maple Mono" "JetBrains Mono" "Consolas"))
                   "JetBrains Mono"))))

(ert-deftest my/ui-font-selection-gracefully-handles-no-match ()
  (cl-letf (((symbol-function 'font-family-list)
             (lambda (&optional _frame) '("Courier New"))))
    (should-not (my/ui--first-available-font '("Maple Mono" "Iosevka")))))

(ert-deftest my/ui-defaults-to-a-modern-dark-theme ()
  (should (eq my/ui-dark-theme 'doom-one))
  (should (eq my/ui-light-theme 'doom-one-light))
  (should (= my/ui-font-height 110))
  (should (eq (lookup-key global-map (kbd "<f6>")) #'my/toggle-ui-theme)))

(ert-deftest my/ui-theme-toggle-is-reversible ()
  (let ((my/ui-theme my/ui-dark-theme))
    (cl-letf (((symbol-function 'my/load-ui-theme) #'ignore))
      (my/toggle-ui-theme)
      (should (eq my/ui-theme my/ui-light-theme))
      (my/toggle-ui-theme)
      (should (eq my/ui-theme my/ui-dark-theme)))))

(ert-deftest my/ui-font-fallbacks-target-the-current-frame-fontset ()
  (let ((answers '("JetBrains Mono" "Segoe UI"
                   "Microsoft YaHei UI" "Segoe UI Emoji"))
        (default-frame-alist nil)
        fontset-calls)
    (cl-letf (((symbol-function 'display-graphic-p)
               (lambda (&optional _frame) t))
              ((symbol-function 'my/ui--first-available-font)
               (lambda (&rest _)
                 (prog1 (car answers)
                   (setq answers (cdr answers)))))
              ((symbol-function 'set-face-attribute) #'ignore)
              ((symbol-function 'set-fontset-font)
               (lambda (&rest arguments)
                 (push arguments fontset-calls))))
      (my/setup-default-font (selected-frame)))
    (should (= (length fontset-calls) 5))
    (should (seq-every-p (lambda (arguments) (null (car arguments)))
                         fontset-calls))
    (should (equal (nth 1 (car fontset-calls))
                   '(#x1f000 . #x1faff)))))

(provide 'init-appearance-test)
;;; init-appearance-test.el ends here
