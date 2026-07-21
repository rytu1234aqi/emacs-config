;;; init-dashboard-test.el --- Tests for the start page -*- lexical-binding: t; -*-

(require 'ert)
(require 'seq)
(require 'init-dashboard)

(ert-deftest rytu/dashboard-is-the-initial-buffer ()
  (should (functionp initial-buffer-choice))
  (should (eq (funcall initial-buffer-choice)
              (get-buffer-create dashboard-buffer-name))))

(ert-deftest rytu/dashboard-keeps-custom-commands-and-keys ()
  (should (commandp 'rytu/dashboard-agenda-today))
  (should (commandp 'rytu/dashboard-agenda-week))
  (should (commandp 'rytu/dashboard-recent-files))
  (should (commandp 'rytu/dashboard-edit-config))
  (should (eq (lookup-key dashboard-mode-map (kbd "a")) #'org-agenda))
  (should (eq (lookup-key dashboard-mode-map (kbd "t"))
              #'rytu/dashboard-agenda-today))
  (should (eq (lookup-key dashboard-mode-map (kbd "w"))
              #'rytu/dashboard-agenda-week))
  (should (eq (lookup-key dashboard-mode-map (kbd "e"))
              #'rytu/dashboard-edit-config))
  (should (eq (lookup-key dashboard-mode-map (kbd "g"))
              #'dashboard-refresh-buffer)))

(ert-deftest rytu/dashboard-uses-banner-icons-and-chinese-names ()
  (should (file-exists-p rytu/dashboard-banner))
  (should (equal dashboard-startup-banner rytu/dashboard-banner))
  (should (eq dashboard-icon-type 'nerd-icons))
  (should dashboard-set-heading-icons)
  (should (equal (cdr (assoc "Recent Files:" dashboard-item-names))
                 "最近文件")))

(ert-deftest rytu/dashboard-renders-sections ()
  (let ((dashboard-items '((recents . 3) (projects . 2)))
        ;; 批量模式无法显示图片，退回字符画横幅。
        (dashboard-startup-banner 'ascii))
    (rytu/dashboard-open)
    (with-current-buffer dashboard-buffer-name
      (should (derived-mode-p 'dashboard-mode))
      (should (string-match-p "Emacs 已就绪" (buffer-string)))
      ;; 栏目中文名通过 overlay 的 display 属性呈现，底层文本保持英文。
      (should (string-match-p "Recent Files:" (buffer-string)))
      (should (seq-some (lambda (ov)
                          (equal (overlay-get ov 'display) "最近文件"))
                        (overlays-in (point-min) (point-max)))))))

(provide 'init-dashboard-test)
;;; init-dashboard-test.el ends here
