;;; init-notion-org.el --- Read-only Notion task mirror for Org -*- lexical-binding: t; -*-

;;; Commentary:

;; Pull structured task properties from the user's Notion Tasks data source
;; into a generated, read-only Org file.  Notion remains authoritative during
;; this first integration phase, so local edits can never overwrite Notion.

;;; Code:

(require 'auth-source)
(require 'cl-lib)
(require 'json)
(require 'org)
(require 'org-agenda)
(require 'seq)
(require 'subr-x)
(require 'url)
(require 'url-http)

(defgroup rytu-notion nil
  "Personal Notion and Org integration."
  :group 'org)

(defcustom rytu/notion-api-version "2026-03-11"
  "Notion API version used by the task mirror."
  :type 'string
  :group 'rytu-notion)

(defcustom rytu/notion-tasks-data-source-id
  "2ea0b0d4-fc8d-816c-9476-000b9f6f7288"
  "Data source ID for the Life OS Tasks database."
  :type 'string
  :group 'rytu-notion)

(defcustom rytu/notion-tasks-file
  (expand-file-name
   "notion/tasks.org"
   (if (boundp 'rytu/org-directory)
       rytu/org-directory
     "~/org/"))
  "Generated Org file containing the Notion task mirror."
  :type 'file
  :group 'rytu-notion)

(defcustom rytu/notion-token-environment-variables
  '("NOTION_API_TOKEN" "NOTION_TOKEN")
  "Environment variables checked before `auth-source' for a Notion token."
  :type '(repeat string)
  :group 'rytu-notion)

(defcustom rytu/notion-keychain-service "rytu-emacs-notion"
  "macOS Keychain service used to store the Notion token."
  :type 'string
  :group 'rytu-notion)

(defcustom rytu/notion-keychain-account "notion"
  "macOS Keychain account used to store the Notion token."
  :type 'string
  :group 'rytu-notion)

(defcustom rytu/notion-included-statuses
  '("TODO" "NEXT" "DOING" "WAIT" "MAYBE" "DONE" "CANCELLED")
  "Notion Status values that may be rendered in the Org mirror."
  :type '(repeat string)
  :group 'rytu-notion)

(defcustom rytu/notion-include-unclassified-tasks nil
  "When non-nil, include legacy tasks whose Notion Status is empty.

An unfinished legacy task becomes TODO and one whose Done checkbox is
checked becomes DONE.  The default is nil so old backlog items cannot flood
the Agenda before they have been deliberately classified in Notion."
  :type 'boolean
  :group 'rytu-notion)

(defcustom rytu/notion-request-timeout 30
  "Seconds to wait for each synchronous Notion API request."
  :type 'integer
  :group 'rytu-notion)

(defconst rytu/notion--status-order
  '(("DOING" . 0)
    ("NEXT" . 1)
    ("TODO" . 2)
    ("WAIT" . 3)
    ("MAYBE" . 4)
    ("DONE" . 5)
    ("CANCELLED" . 6))
  "Sort order for task statuses in the generated file.")

(defun rytu/notion--secret-value (secret)
  "Return the string represented by auth-source SECRET."
  (let ((value (if (functionp secret) (funcall secret) secret)))
    (when (stringp value)
      (string-trim value))))

(defun rytu/notion--keychain-token ()
  "Return the Notion token stored in macOS Keychain, if available."
  (when (and (eq system-type 'darwin)
             (file-executable-p "/usr/bin/security"))
    (with-temp-buffer
      (when (zerop
             (call-process
              "/usr/bin/security" nil t nil
              "find-generic-password"
              "-a" rytu/notion-keychain-account
              "-s" rytu/notion-keychain-service
              "-w"))
        (let ((token (string-trim (buffer-string))))
          (unless (string-empty-p token)
            token))))))

(defun rytu/notion--token ()
  "Return a Notion token without storing it in source code."
  (or (seq-some
       (lambda (name)
         (when-let ((value (getenv name)))
           (unless (string-empty-p value)
             (string-trim value))))
       rytu/notion-token-environment-variables)
      (when-let* ((match
                   (car (auth-source-search
                         :host "api.notion.com"
                         :require '(:secret)
                         :max 1)))
                  (secret (plist-get match :secret)))
        (rytu/notion--secret-value secret))
      (rytu/notion--keychain-token)
      (user-error
       "Notion token not found; run M-x rytu/notion-auth-help")))

(defun rytu/notion--response-body-start ()
  "Return the first position after HTTP headers in the current buffer."
  (or (and (boundp 'url-http-end-of-headers)
           url-http-end-of-headers
           (if (markerp url-http-end-of-headers)
               (marker-position url-http-end-of-headers)
             url-http-end-of-headers))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward "\r?\n\r?\n" nil t)
          (point)))
      (point-min)))

(defun rytu/notion--parse-json (text)
  "Parse JSON TEXT into alists and lists."
  (json-parse-string text
                     :object-type 'alist
                     :array-type 'list
                     :null-object nil
                     :false-object nil))

(defun rytu/notion--request (method endpoint &optional data)
  "Send METHOD request to Notion ENDPOINT with optional alist DATA."
  (let* ((url-request-method method)
         (url-request-extra-headers
          `(("Authorization" . ,(concat "Bearer " (rytu/notion--token)))
            ("Notion-Version" . ,rytu/notion-api-version)
            ("Content-Type" . "application/json")
            ("Accept" . "application/json")))
         (url-request-data
          (when data
            (encode-coding-string (json-encode data) 'utf-8)))
         (url (concat "https://api.notion.com/v1/" endpoint))
         (buffer
          (url-retrieve-synchronously
           url t t rytu/notion-request-timeout)))
    (unless buffer
      (user-error "Notion request timed out: %s" endpoint))
    (unwind-protect
        (with-current-buffer buffer
          (let* ((status (or (and (boundp 'url-http-response-status)
                                  url-http-response-status)
                             0))
                 (start (rytu/notion--response-body-start))
                 (body
                  (decode-coding-string
                   (buffer-substring-no-properties start (point-max))
                   'utf-8))
                 (parsed
                  (condition-case nil
                      (rytu/notion--parse-json body)
                    (error nil))))
            (if (and (>= status 200) (< status 300))
                (or parsed
                    (user-error "Notion returned invalid JSON"))
              (let ((detail
                     (or (and parsed (alist-get 'message parsed))
                         (string-trim body)
                         "unknown error")))
                (user-error "Notion API error %s: %s" status detail)))))
      (kill-buffer buffer))))

(defun rytu/notion--query-task-pages ()
  "Return every page from the configured Notion Tasks data source."
  (let ((endpoint
         (format "data_sources/%s/query"
                 rytu/notion-tasks-data-source-id))
        (cursor nil)
        (pages nil)
        has-more)
    (setq has-more t)
    (while has-more
      (let* ((payload
              (append '((page_size . 100))
                      (when cursor
                        `((start_cursor . ,cursor)))))
             (response (rytu/notion--request "POST" endpoint payload)))
        (setq pages
              (nconc pages (copy-sequence (alist-get 'results response)))
              has-more (alist-get 'has_more response)
              cursor (alist-get 'next_cursor response))))
    pages))

(defun rytu/notion--property (page name)
  "Return property NAME from Notion PAGE."
  (alist-get (intern name) (alist-get 'properties page)))

(defun rytu/notion--plain-text (items)
  "Concatenate plain text from Notion rich-text ITEMS."
  (mapconcat
   (lambda (item)
     (or (alist-get 'plain_text item) ""))
   items
   ""))

(defun rytu/notion--title (page)
  "Return the title string from Notion PAGE."
  (let ((property (rytu/notion--property page "Name")))
    (string-trim
     (rytu/notion--plain-text (alist-get 'title property)))))

(defun rytu/notion--select-name (page property-name)
  "Return selected option name for PROPERTY-NAME in Notion PAGE."
  (let* ((property (rytu/notion--property page property-name))
         (value (or (alist-get 'select property)
                    (alist-get 'status property))))
    (alist-get 'name value)))

(defun rytu/notion--checkbox-p (page property-name)
  "Return non-nil when PAGE checkbox PROPERTY-NAME is checked."
  (eq t (alist-get 'checkbox
                   (rytu/notion--property page property-name))))

(defun rytu/notion--date (page property-name)
  "Return Notion date alist for PAGE PROPERTY-NAME."
  (alist-get 'date (rytu/notion--property page property-name)))

(defun rytu/notion--relation-ids (page property-name)
  "Return related page IDs for PAGE PROPERTY-NAME."
  (delq nil
        (mapcar
         (lambda (item) (alist-get 'id item))
         (alist-get 'relation
                    (rytu/notion--property page property-name)))))

(defun rytu/notion--task-status (page)
  "Return the Org TODO state for Notion PAGE, or nil when excluded."
  (let ((status (rytu/notion--select-name page "Status")))
    (when (and (null status)
               rytu/notion-include-unclassified-tasks)
      (setq status
            (if (rytu/notion--checkbox-p page "Done")
                "DONE"
              "TODO")))
    (and (member status rytu/notion-included-statuses)
         status)))

(defun rytu/notion--clean-one-line (value)
  "Return VALUE as trimmed, single-line text."
  (when value
    (string-trim
     (replace-regexp-in-string "[\n\r\t ]+" " " value))))

(defun rytu/notion--org-timestamp (iso)
  "Convert ISO date or datetime string ISO into an active Org timestamp."
  (when (and iso (not (string-empty-p iso)))
    (condition-case nil
        (if (string-match
             "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'"
             iso)
            (let ((time
                   (encode-time
                    0 0 12
                    (string-to-number (match-string 3 iso))
                    (string-to-number (match-string 2 iso))
                    (string-to-number (match-string 1 iso)))))
              (format-time-string "<%Y-%m-%d %a>" time))
          (format-time-string
           "<%Y-%m-%d %a %H:%M>"
           (date-to-time iso)))
      (error nil))))

(defun rytu/notion--org-id (notion-id)
  "Return a stable Org ID derived from NOTION-ID."
  (concat "notion-" (replace-regexp-in-string "-" "" notion-id)))

(defun rytu/notion--task-data (page)
  "Convert Notion PAGE into a normalized task plist.

Return nil when the page has no usable title or is outside the configured
status policy."
  (let* ((title (rytu/notion--clean-one-line
                 (rytu/notion--title page)))
         (status (rytu/notion--task-status page))
         (priority (rytu/notion--select-name page "Priority"))
         (date (rytu/notion--date page "Date"))
         (deadline (rytu/notion--date page "Deadline"))
         (notion-id (alist-get 'id page))
         (url (alist-get 'url page))
         (edited (alist-get 'last_edited_time page))
         (created (alist-get 'created_time page))
         (project-ids
          (rytu/notion--relation-ids page "Project")))
    (when (and title
               (not (string-empty-p title))
               status
               notion-id
               url)
      (let* ((date-start (alist-get 'start date))
             (date-end (alist-get 'end date))
             (deadline-start (alist-get 'start deadline))
             (deadline-end (alist-get 'end deadline))
             (hash
              (secure-hash
               'sha256
               (prin1-to-string
                (list title status priority date-start date-end
                      deadline-start deadline-end project-ids edited)))))
        (list :title title
              :status status
              :priority priority
              :scheduled (rytu/notion--org-timestamp date-start)
              :date-start date-start
              :date-end date-end
              :deadline (rytu/notion--org-timestamp deadline-start)
              :deadline-start deadline-start
              :deadline-end deadline-end
              :notion-id notion-id
              :org-id (rytu/notion--org-id notion-id)
              :url url
              :created created
              :edited edited
              :project-ids project-ids
              :hash hash)))))

(defun rytu/notion--task-less-p (left right)
  "Return non-nil when normalized task LEFT should sort before RIGHT."
  (let* ((left-status (plist-get left :status))
         (right-status (plist-get right :status))
         (left-rank
          (or (alist-get left-status rytu/notion--status-order
                         nil nil #'string=)
              99))
         (right-rank
          (or (alist-get right-status rytu/notion--status-order
                         nil nil #'string=)
              99))
         (left-date (or (plist-get left :date-start)
                        (plist-get left :deadline-start)
                        "9999-12-31"))
         (right-date (or (plist-get right :date-start)
                         (plist-get right :deadline-start)
                         "9999-12-31")))
    (or (< left-rank right-rank)
        (and (= left-rank right-rank)
             (or (string< left-date right-date)
                 (and (string= left-date right-date)
                      (string-lessp
                       (plist-get left :title)
                       (plist-get right :title))))))))

(defun rytu/notion--insert-property (name value)
  "Insert Org property NAME with VALUE when VALUE is non-empty."
  (when (and value
             (not (and (stringp value) (string-empty-p value))))
    (insert ":" name ": "
            (rytu/notion--clean-one-line
             (if (stringp value) value (format "%s" value)))
            "\n")))

(defun rytu/notion--render-task (task)
  "Return Org text representing normalized TASK."
  (with-temp-buffer
    (insert "* " (plist-get task :status) " ")
    (when-let ((priority (plist-get task :priority)))
      (insert "[#" priority "] "))
    (insert (plist-get task :title) " :notion:\n")
    (when-let ((scheduled (plist-get task :scheduled)))
      (insert "SCHEDULED: " scheduled "\n"))
    (when-let ((deadline (plist-get task :deadline)))
      (insert "DEADLINE: " deadline "\n"))
    (insert ":PROPERTIES:\n")
    (rytu/notion--insert-property "ID" (plist-get task :org-id))
    (rytu/notion--insert-property
     "NOTION_ID" (plist-get task :notion-id))
    (rytu/notion--insert-property
     "NOTION_URL" (plist-get task :url))
    (rytu/notion--insert-property
     "NOTION_CREATED" (plist-get task :created))
    (rytu/notion--insert-property
     "NOTION_EDITED" (plist-get task :edited))
    (rytu/notion--insert-property
     "NOTION_DATE_END" (plist-get task :date-end))
    (rytu/notion--insert-property
     "NOTION_DEADLINE_END" (plist-get task :deadline-end))
    (rytu/notion--insert-property
     "NOTION_PROJECT_IDS"
     (when-let ((ids (plist-get task :project-ids)))
       (string-join ids ",")))
    (rytu/notion--insert-property "SYNC_STATE" "READ_ONLY")
    (rytu/notion--insert-property
     "SYNC_HASH" (plist-get task :hash))
    (insert ":END:\n\n")
    (buffer-string)))

(defun rytu/notion--render-file (tasks)
  "Return a complete generated Org file for normalized TASKS."
  (with-temp-buffer
    (insert "#+title: Notion Tasks\n"
            "#+startup: overview\n"
            "#+filetags: :notion:\n"
            "#+category: Notion\n\n"
            "# AUTO-GENERATED READ-ONLY MIRROR.\n"
            "# Edit tasks in Notion, then run `rytu/notion-pull-tasks`.\n"
            "# Tasks without Status are intentionally excluded by default.\n\n")
    (dolist (task (sort (copy-sequence tasks)
                        #'rytu/notion--task-less-p))
      (insert (rytu/notion--render-task task)))
    (buffer-string)))

(defun rytu/notion--write-if-changed (content)
  "Atomically write CONTENT to the task mirror.

Return non-nil when the file changed."
  (let* ((file (expand-file-name rytu/notion-tasks-file))
         (directory (file-name-directory file))
         (existing
          (when (file-readable-p file)
            (with-temp-buffer
              (insert-file-contents file)
              (buffer-string)))))
    (if (equal existing content)
        nil
      (make-directory directory t)
      (let ((temporary (make-temp-file
                        (expand-file-name ".notion-tasks-" directory))))
        (unwind-protect
            (let ((coding-system-for-write 'utf-8-unix))
              (with-temp-file temporary
                (insert content))
              (set-file-modes temporary #o600)
              (rename-file temporary file t))
          (when (file-exists-p temporary)
            (delete-file temporary))))
      t)))

(defun rytu/notion--revert-mirror-buffer ()
  "Refresh an existing task mirror buffer after a pull."
  (when-let ((buffer
              (get-file-buffer
               (expand-file-name rytu/notion-tasks-file))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (revert-buffer t t t)))))

(defun rytu/notion--refresh-agenda ()
  "Refresh Agenda file discovery and the current Agenda view."
  (when (fboundp 'rytu/org-refresh-agenda-files)
    (rytu/org-refresh-agenda-files))
  (when (derived-mode-p 'org-agenda-mode)
    (org-agenda-redo)))

;;;###autoload
(defun rytu/notion-store-token-in-keychain (token)
  "Securely store Notion TOKEN in the current macOS user's Keychain."
  (interactive (list (read-passwd "Notion token: ")))
  (unless (and (eq system-type 'darwin)
               (file-executable-p "/usr/bin/security"))
    (user-error "macOS Keychain is not available"))
  (when (string-empty-p token)
    (user-error "The token cannot be empty"))
  (let ((output (generate-new-buffer " *Notion Keychain*")))
    (unwind-protect
        (with-temp-buffer
          (insert token "\n")
          (let ((status
                 (call-process-region
                  (point-min) (point-max)
                  "/usr/bin/security"
                  t output nil
                  "add-generic-password"
                  "-U"
                  "-a" rytu/notion-keychain-account
                  "-s" rytu/notion-keychain-service
                  "-w")))
            (unless (zerop status)
              (user-error
               "Keychain rejected the token: %s"
               (with-current-buffer output
                 (string-trim (buffer-string)))))
            (message "Notion token stored securely in macOS Keychain")))
      (when (buffer-live-p output)
        (kill-buffer output))
      (clear-string token))))

;;;###autoload
(defun rytu/notion-pull-tasks ()
  "Pull Notion Tasks into a generated, read-only Org Agenda file."
  (interactive)
  (message "Notion: pulling task properties...")
  (let* ((pages (rytu/notion--query-task-pages))
         (tasks (delq nil (mapcar #'rytu/notion--task-data pages)))
         (content (rytu/notion--render-file tasks))
         (changed (rytu/notion--write-if-changed content)))
    (when changed
      (rytu/notion--revert-mirror-buffer))
    (rytu/notion--refresh-agenda)
    (message
     "Notion: %d classified tasks mirrored from %d pages%s"
     (length tasks)
     (length pages)
     (if changed " (file updated)" " (already current)"))))

(defun rytu/notion--url-at-point ()
  "Return NOTION_URL for the Org or Agenda entry at point."
  (cond
   ((derived-mode-p 'org-agenda-mode)
    (let ((marker
           (or (get-text-property
                (line-beginning-position) 'org-hd-marker)
               (get-text-property
                (line-beginning-position) 'org-marker))))
      (when (markerp marker)
        (with-current-buffer (marker-buffer marker)
          (save-excursion
            (goto-char marker)
            (org-entry-get nil "NOTION_URL"))))))
   ((derived-mode-p 'org-mode)
    (save-excursion
      (when (org-before-first-heading-p)
        (user-error "Point is not on a Notion task"))
      (org-back-to-heading t)
      (org-entry-get nil "NOTION_URL")))))

;;;###autoload
(defun rytu/notion-open-at-point ()
  "Open the Notion page corresponding to the task at point."
  (interactive)
  (if-let ((url (rytu/notion--url-at-point)))
      (browse-url url)
    (user-error "This entry has no NOTION_URL")))

;;;###autoload
(defun rytu/notion-open-tasks-file ()
  "Open the generated Notion task mirror."
  (interactive)
  (if (file-readable-p rytu/notion-tasks-file)
      (find-file rytu/notion-tasks-file)
    (user-error "Run M-x rytu/notion-pull-tasks first")))

;;;###autoload
(defun rytu/notion-auth-help ()
  "Show one-time authentication and daily-use instructions."
  (interactive)
  (with-help-window "*Notion Org Setup*"
    (princ
     (concat
      "Notion → Org 任务镜像\n\n"
      "首次配置\n"
      "1. 创建 Notion 个人访问令牌或内部连接。\n"
      "2. 给它 Life OS Tasks 数据库的读取权限。\n"
      "3. 执行 M-x rytu/notion-store-token-in-keychain 并粘贴令牌。\n"
      "4. 执行 M-x rytu/notion-pull-tasks。\n\n"
      "也可以使用 NOTION_API_TOKEN 环境变量，或在 auth-source 中\n"
      "保存 api.notion.com 对应的密钥。\n\n"
      "日常使用\n"
      "C-c N s   拉取 Notion 任务并刷新 Agenda\n"
      "C-c N t   打开生成的只读任务镜像\n"
      "C-c N o   在 Notion 中打开光标所在任务\n"
      "C-c N k   在 macOS 钥匙串中保存或替换令牌\n"
      "C-c a d   打开每日 Agenda 仪表盘\n\n"
      "默认只同步已经填写 Status 的任务。给旧任务设置 TODO、NEXT、\n"
      "DOING、WAIT、MAYBE、DONE 或 CANCELLED 后，它才会进入 Emacs，\n"
      "这样不会让历史积压一次性淹没 Agenda。\n"))))

(defun rytu/notion--maybe-make-buffer-read-only ()
  "Make the generated Notion mirror read-only when it is visited."
  (when (and buffer-file-name
             (string-equal
              (expand-file-name buffer-file-name)
              (expand-file-name rytu/notion-tasks-file)))
    (read-only-mode 1)))

(add-hook 'org-mode-hook #'rytu/notion--maybe-make-buffer-read-only)

(defvar rytu/notion-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "s") #'rytu/notion-pull-tasks)
    (define-key map (kbd "t") #'rytu/notion-open-tasks-file)
    (define-key map (kbd "o") #'rytu/notion-open-at-point)
    (define-key map (kbd "k") #'rytu/notion-store-token-in-keychain)
    (define-key map (kbd "?") #'rytu/notion-auth-help)
    map)
  "Keymap for Notion and Org integration commands.")

(global-set-key (kbd "C-c N") rytu/notion-command-map)

(provide 'init-notion-org)

;;; init-notion-org.el ends here
