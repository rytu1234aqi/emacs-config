;;; init-notion-org-test.el --- Tests for Notion Org mirror -*- lexical-binding: t; -*-

(require 'ert)
(require 'init-notion-org)

(defconst rytu/notion-test--page-json
  "{
     \"object\": \"page\",
     \"id\": \"11111111-2222-3333-4444-555555555555\",
     \"created_time\": \"2026-07-15T08:00:00.000Z\",
     \"last_edited_time\": \"2026-07-17T01:30:00.000Z\",
     \"url\": \"https://www.notion.so/11111111222233334444555555555555\",
     \"properties\": {
       \"Name\": {
         \"type\": \"title\",
         \"title\": [{\"plain_text\": \"Write report\"}]
       },
       \"Status\": {
         \"type\": \"select\",
         \"select\": {\"name\": \"NEXT\"}
       },
       \"Priority\": {
         \"type\": \"select\",
         \"select\": {\"name\": \"A\"}
       },
       \"Date\": {
         \"type\": \"date\",
         \"date\": {\"start\": \"2026-07-18\", \"end\": null}
       },
       \"Deadline\": {
         \"type\": \"date\",
         \"date\": {\"start\": \"2026-07-20\", \"end\": null}
       },
       \"Project\": {
         \"type\": \"relation\",
         \"relation\": [{\"id\": \"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\"}]
       },
       \"Done\": {\"type\": \"checkbox\", \"checkbox\": false}
     }
   }"
  "Representative Notion task page used by tests.")

(defun rytu/notion-test--page ()
  "Return a freshly parsed representative Notion page."
  (rytu/notion--parse-json rytu/notion-test--page-json))

(ert-deftest rytu/notion-task-mapping ()
  (let* ((task (rytu/notion--task-data (rytu/notion-test--page)))
         (org-text (rytu/notion--render-task task)))
    (should (string-match-p
             (regexp-quote "* NEXT [#A] Write report :notion:")
             org-text))
    (should (string-match-p
             (regexp-quote "SCHEDULED: <2026-07-18")
             org-text))
    (should (string-match-p
             (regexp-quote "DEADLINE: <2026-07-20")
             org-text))
    (should (string-match-p
             (regexp-quote
              ":ID: notion-11111111222233334444555555555555")
             org-text))
    (should (string-match-p
             (regexp-quote
              ":NOTION_PROJECT_IDS: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
             org-text))
    (should (string-match-p
             (regexp-quote ":SYNC_STATE: READ_ONLY")
             org-text))))

(ert-deftest rytu/notion-unclassified-task-is-excluded-by-default ()
  (let ((page (rytu/notion-test--page))
        (rytu/notion-include-unclassified-tasks nil))
    (setf (alist-get 'select
                     (rytu/notion--property page "Status"))
          nil)
    (should-not (rytu/notion--task-data page))))

(ert-deftest rytu/notion-unclassified-task-can-use-legacy-done ()
  (let ((page (rytu/notion-test--page))
        (rytu/notion-include-unclassified-tasks t))
    (setf (alist-get 'select
                     (rytu/notion--property page "Status"))
          nil)
    (setf (alist-get 'checkbox
                     (rytu/notion--property page "Done"))
          t)
    (should (equal "DONE"
                   (plist-get (rytu/notion--task-data page)
                              :status)))))

(ert-deftest rytu/notion-write-is-idempotent ()
  (let* ((temporary-directory (make-temp-file "notion-org-test-" t))
         (rytu/notion-tasks-file
          (expand-file-name "notion/tasks.org" temporary-directory))
         (content "#+title: Test\n"))
    (unwind-protect
        (progn
          (should (rytu/notion--write-if-changed content))
          (should-not (rytu/notion--write-if-changed content))
          (should (equal content
                         (with-temp-buffer
                           (insert-file-contents rytu/notion-tasks-file)
                           (buffer-string)))))
      (delete-directory temporary-directory t))))

(ert-deftest rytu/notion-keychain-store-keeps-token-off-command-line ()
  (let ((token (copy-sequence "test-notion-token"))
        captured-arguments
        captured-input)
    (cl-letf (((symbol-function 'call-process-region)
               (lambda (start end _program _delete _destination
                              _display &rest arguments)
                 (setq captured-arguments arguments
                       captured-input
                       (buffer-substring-no-properties start end))
                 0)))
      (rytu/notion-store-token-in-keychain token))
    (should (equal captured-input "test-notion-token\n"))
    (should-not (member "test-notion-token" captured-arguments))))

(provide 'init-notion-org-test)

;;; init-notion-org-test.el ends here
