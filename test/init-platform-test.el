;;; init-platform-test.el --- Cross-platform configuration tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'init-platform)
(require 'init-unity)

(ert-deftest my/platform-prefers-an-explicit-compiler ()
  (cl-letf (((symbol-function 'executable-find)
             (lambda (program)
               (pcase program
                 ("custom-clang" "/opt/custom/bin/custom-clang")
                 ("clang" "/usr/bin/clang")
                 (_ nil)))))
    (should (equal
             (my/platform-first-executable '("clang" "gcc") "custom-clang")
             "/opt/custom/bin/custom-clang"))))

(ert-deftest my/platform-refresh-handles-the-native-path-separator ()
  (let* ((process-environment (copy-sequence process-environment))
         (exec-path '("/existing/bin"))
         (extra (expand-file-name "extra-bin" temporary-file-directory))
         (my/platform-extra-exec-paths (list extra)))
    (setenv "PATH" "/existing/bin")
    (cl-letf (((symbol-function 'my/platform-default-exec-paths)
               (lambda () nil))
              ((symbol-function 'file-directory-p)
               (lambda (directory) (equal directory extra))))
      (my/platform-refresh-environment)
      (should (equal (car exec-path) extra))
      (should (equal (car (my/platform--path-components)) extra)))))

(ert-deftest my/unity-builds-platform-specific-editor-candidates ()
  (let ((root (file-name-as-directory
               (expand-file-name "Unity/Hub/Editor"
                                 temporary-file-directory)))
        (version "6000.0.50f1"))
    (let ((system-type 'darwin))
      (should
       (equal (car (my/unity--editor-candidates root version))
              (expand-file-name
               "6000.0.50f1/Unity.app/Contents/MacOS/Unity" root))))
    (let ((system-type 'windows-nt))
      (should
       (equal (car (my/unity--editor-candidates root version))
              (expand-file-name "6000.0.50f1/Editor/Unity.exe" root))))))

(ert-deftest my/unity-finds-emacs-app-client-on-macos ()
  (let* ((system-type 'darwin)
         (invocation-directory "/Applications/Emacs.app/Contents/MacOS/")
         (candidate (expand-file-name "bin/emacsclient"
                                      invocation-directory)))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (_program) nil))
              ((symbol-function 'file-regular-p)
               (lambda (file) (equal file candidate))))
      (should (equal (my/unity--emacsclient-program) candidate)))))

(provide 'init-platform-test)
;;; init-platform-test.el ends here
