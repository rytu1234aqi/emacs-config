;;; init-appearance.el --- Fonts and color themes -*- lexical-binding: t; -*-

;;; 主题和字体集中在这里，避免系统缺少某一种字体时悄悄退回 Courier New。

(require 'seq)
(require 'use-package)

(defgroup my/ui nil
  "Personal appearance settings."
  :group 'faces)

(defcustom my/ui-dark-theme 'doom-one
  "Dark theme used by `my/toggle-ui-theme'."
  :type 'symbol
  :group 'my/ui)

(defcustom my/ui-light-theme 'doom-one-light
  "Light theme used by `my/toggle-ui-theme'."
  :type 'symbol
  :group 'my/ui)

(defcustom my/ui-theme my/ui-dark-theme
  "Theme loaded for graphical frames."
  :type 'symbol
  :group 'my/ui)

(defcustom my/ui-font-height 110
  "Default font height in tenths of a point."
  :type 'integer
  :group 'my/ui)

(defcustom my/ui-fixed-font-families
  '("Maple Mono NF CN"
    "Maple Mono"
    "JetBrains Mono"
    "Cascadia Code"
    "Iosevka"
    "Fira Code"
    "SF Mono"
    "Menlo"
    "DejaVu Sans Mono"
    "Consolas")
  "Preferred fixed-pitch fonts, in priority order."
  :type '(repeat string)
  :group 'my/ui)

(defcustom my/ui-variable-font-families
  '("Segoe UI" "Inter" "SF Pro Text" "Noto Sans" "Arial")
  "Preferred variable-pitch UI fonts, in priority order."
  :type '(repeat string)
  :group 'my/ui)

(defcustom my/ui-cjk-font-families
  '("Maple Mono NF CN"
    "Sarasa Mono SC"
    "Noto Sans Mono CJK SC"
    "Microsoft YaHei UI"
    "Microsoft YaHei"
    "PingFang SC")
  "Preferred CJK fonts, in priority order."
  :type '(repeat string)
  :group 'my/ui)

(defcustom my/ui-emoji-font-families
  '("Segoe UI Emoji" "Noto Color Emoji" "Apple Color Emoji")
  "Preferred Emoji fonts, in priority order."
  :type '(repeat string)
  :group 'my/ui)

(defvar my/ui-active-fixed-font nil
  "Fixed-pitch font selected for the most recently configured frame.")

(defvar my/ui-active-cjk-font nil
  "CJK font selected for the most recently configured frame.")

(use-package doom-themes
  :ensure t
  :demand t
  :init
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t))

(defun my/load-ui-theme (&optional frame)
  "Load `my/ui-theme' when FRAME is graphical.

FRAME is accepted so this function can be used by
`after-make-frame-functions'."
  (let ((frame (or frame (selected-frame))))
    (when (display-graphic-p frame)
      (unless (memq my/ui-theme custom-enabled-themes)
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme my/ui-theme t)))))

(defun my/toggle-ui-theme ()
  "Toggle between the configured dark and light themes."
  (interactive)
  (setq my/ui-theme
        (if (eq my/ui-theme my/ui-dark-theme)
            my/ui-light-theme
          my/ui-dark-theme))
  (my/load-ui-theme))

(defun my/ui--first-available-font (candidates &optional frame)
  "Return the first installed font from CANDIDATES for FRAME."
  (let ((families (font-family-list frame)))
    (seq-find (lambda (family) (member family families)) candidates)))

(defun my/setup-default-font (&optional frame)
  "Apply the preferred Latin, UI, CJK and Emoji fonts to FRAME."
  (let ((frame (or frame (selected-frame))))
    (when (display-graphic-p frame)
      (with-selected-frame frame
        (let ((fixed (my/ui--first-available-font
                      my/ui-fixed-font-families frame))
              (variable (my/ui--first-available-font
                         my/ui-variable-font-families frame))
              (cjk (my/ui--first-available-font
                    my/ui-cjk-font-families frame))
              (emoji (my/ui--first-available-font
                      my/ui-emoji-font-families frame)))
          (when fixed
            (setq my/ui-active-fixed-font fixed)
            (set-face-attribute 'default frame
                                :family fixed
                                :height my/ui-font-height
                                :weight 'regular)
            (set-face-attribute 'fixed-pitch frame
                                :family fixed
                                :height my/ui-font-height)
            (setf (alist-get 'font default-frame-alist)
                  (format "%s-%d" fixed (/ my/ui-font-height 10))))
          (when variable
            (set-face-attribute 'variable-pitch frame
                                :family variable
                                :height 1.0
                                :weight 'regular))
          (when cjk
            (setq my/ui-active-cjk-font cjk)
            (dolist (charset '(han cjk-misc kana bopomofo))
              (set-fontset-font nil charset (font-spec :family cjk)
                                frame 'prepend)))
          (when emoji
            ;; Windows 的 w32 字体后端不会始终把补充平面字符归入
            ;; `emoji' script，直接覆盖 Emoji Unicode 区间更可靠。
            (set-fontset-font nil '(#x1f000 . #x1faff)
                              (font-spec :family emoji)
                              frame 'prepend)))))))

(my/load-ui-theme)
(my/setup-default-font)
(add-hook 'after-make-frame-functions #'my/load-ui-theme)
(add-hook 'after-make-frame-functions #'my/setup-default-font)
(global-set-key (kbd "<f6>") #'my/toggle-ui-theme)

(provide 'init-appearance)
;;; init-appearance.el ends here
