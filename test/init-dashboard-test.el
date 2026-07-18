;;; init-dashboard-test.el --- Tests for the personal start page -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'init-dashboard)

(ert-deftest rytu/dashboard-is-the-initial-buffer ()
  (should (eq initial-buffer-choice #'rytu/dashboard-buffer)))

(ert-deftest rytu/dashboard-renders-actions-and-shortcuts ()
  (let ((buffer (rytu/dashboard-buffer)))
    (unwind-protect
        (with-current-buffer buffer
          (should (derived-mode-p 'rytu/dashboard-mode))
          (should (eq (key-binding (kbd "a")) #'org-agenda))
          (should (eq (key-binding (kbd "t"))
                      #'rytu/dashboard-agenda-today))
          (should (string-match-p "EMACS\\|_______" (buffer-string)))
          (should (string-match-p "C-c a" (buffer-string)))
          (should (string-match-p "Agenda 文件" (buffer-string)))
          (should (next-button (point-min))))
      (kill-buffer buffer))))

(ert-deftest rytu/dashboard-can-be-refreshed ()
  (let ((buffer (rytu/dashboard-buffer)))
    (unwind-protect
        (with-current-buffer buffer
          (let ((original (buffer-string)))
            (goto-char (point-max))
            (let ((inhibit-read-only t))
              (insert "temporary text"))
            (rytu/dashboard-refresh)
            (should (equal original (buffer-string)))
            (should-not (buffer-modified-p))))
      (kill-buffer buffer))))

(provide 'init-dashboard-test)
;;; init-dashboard-test.el ends here
