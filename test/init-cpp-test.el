;;; init-cpp-test.el --- Tests for modern C/C++ tooling -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'init)

(ert-deftest my/cpp-defaults-target-a-modern-project-toolchain ()
  (should (equal my/cpp-c-standard "c23"))
  (should (equal my/cpp-cxx-standard "c++23"))
  (should (eq my/cpp-format-on-save 'project))
  (should my/cpp-skip-eglot-for-leetcode)
  (should my/cmake-prefer-ninja)
  (should (equal (car my/cpp-c-compiler-candidates) "clang"))
  (should (equal (car my/cpp-cxx-compiler-candidates) "clang++"))
  (dolist (flag '("--background-index" "--clang-tidy" "--enable-config"))
    (should (member flag my/cpp-clangd-command)))
  (dolist (flag '("-Wall" "-Wextra" "-Wpedantic" "-g3" "-O0"))
    (should (member flag my/cpp-single-file-flags))))

(ert-deftest my/cpp-distinguishes-c-from-cpp-file-conventions ()
  (let ((base (expand-file-name "example" temporary-file-directory)))
    (should (my/cpp--c-source-p (concat base ".c")))
    (should-not (my/cpp--c-source-p (concat base ".C")))
    (should-not (my/cpp--c-source-p (concat base ".cc")))
    (should-not (my/cpp--c-source-p (concat base ".cpp")))))

(ert-deftest my/cpp-standalone-build-is-deterministic-and-debuggable ()
  (let* ((source (expand-file-name "one/example.cpp"
                                   temporary-file-directory))
         (first (my/cpp-single-file-executable source))
         (second (my/cpp-single-file-executable source))
         (other (my/cpp-single-file-executable
                 (expand-file-name "two/example.cpp"
                                   temporary-file-directory))))
    (should (equal first second))
    (should-not (equal first other))
    (should (file-in-directory-p first my/state-directory))))

(ert-deftest my/cpp-single-file-command-uses-modern-debug-flags ()
  (let ((compiler (expand-file-name "tool/clang++" temporary-file-directory))
        (output (expand-file-name "example-bin" temporary-file-directory))
        (source (expand-file-name "example file.cpp"
                                  temporary-file-directory)))
    (cl-letf (((symbol-function 'my/platform-first-executable)
               (lambda (_candidates &optional _explicit) compiler))
              ((symbol-function 'my/cpp-single-file-executable)
               (lambda (&optional _file) output)))
      (let ((command (my/cpp-single-file-compile-command source)))
      (should (string-match-p
               (regexp-quote (shell-quote-argument "-std=c++23")) command))
      (dolist (flag my/cpp-single-file-flags)
        (should (string-match-p
                 (regexp-quote (shell-quote-argument flag)) command)))
      (should (string-suffix-p
               (concat " && " (shell-quote-argument output))
               command))))))

(ert-deftest my/cmake-preset-listing-delegates-resolution-to-cmake ()
  (let ((root (file-name-as-directory temporary-file-directory)))
    (cl-letf (((symbol-function 'my/require-executable)
               (lambda (_program) "cmake"))
              ((symbol-function 'call-process)
               (lambda (&rest _arguments)
                 (insert "Available configure presets:\n\n"
                         "  \"debug\" - Debug build\n"
                         "  \"release\" - Release build\n")
                 0)))
      (should (equal (my/cmake--preset-names root 'configure)
                     '("debug" "release"))))))

(ert-deftest my/cmake-uses-ninja-for-native-windows-compilation-databases ()
  (let ((system-type 'windows-nt)
        (my/cmake-prefer-ninja t))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (program)
                 (and (equal program "ninja") "C:/Tools/ninja.exe"))))
      (should (equal (my/cmake-default-generator-arguments)
                     '("-G" "Ninja"))))))

(ert-deftest my/cmake-explains-when-windows-cannot-generate-clangd-database ()
  (let ((system-type 'windows-nt)
        (my/cmake-prefer-ninja t))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (_program) nil)))
      (should-error (my/cmake-default-generator-arguments)
                    :type 'user-error))))

(ert-deftest my/cpp-finds-clangd-database-in-an-ancestor-build-directory ()
  (let* ((root (file-name-as-directory
                (expand-file-name "codex-cpp-project"
                                  temporary-file-directory)))
         (database (expand-file-name "build/compile_commands.json" root))
         (source-directory (expand-file-name "src/lib/" root)))
    (cl-letf (((symbol-function 'file-readable-p)
               (lambda (file) (equal file database))))
      (should (equal (my/cpp-compilation-database source-directory)
                     database)))))

(ert-deftest my/cpp-enables-inlay-hints-only-for-managed-cpp ()
  (let (argument)
    (with-temp-buffer
      (setq major-mode 'c++-ts-mode
            eglot-managed-mode t
            my/cpp-enable-inlay-hints t)
      (cl-letf (((symbol-function 'eglot-inlay-hints-mode)
                 (lambda (value) (setq argument value))))
        (my/cpp-eglot-managed-setup)))
    (should (= argument 1))))

(ert-deftest my/cpp-leetcode-eglot-policy-remains-user-configurable ()
  (with-temp-buffer
    (setq buffer-file-name
          (expand-file-name "123.cpp" temporary-file-directory))
    (let ((my/cpp-skip-eglot-for-leetcode t)
          started)
      (cl-letf (((symbol-function 'eglot-ensure)
                 (lambda () (setq started t))))
        (my/eglot-maybe-ensure)
        (should-not started)
        (setq my/cpp-skip-eglot-for-leetcode nil)
        (my/eglot-maybe-ensure)
        (should started)))))

(ert-deftest my/cpp-debug-prefers-the-cached-standalone-build ()
  (let* ((root (file-name-as-directory
                (expand-file-name "codex-debug-project"
                                  temporary-file-directory)))
         (source (expand-file-name "src/example.cpp" root))
         (suffix (if (eq system-type 'windows-nt) ".exe" ""))
         (cached (expand-file-name (concat "cache/example" suffix)
                                   temporary-file-directory))
         (source-exe (concat (file-name-sans-extension source) suffix))
         (default-exe (expand-file-name
                       (if (eq system-type 'windows-nt) "a.exe" "a.out")
                       root))
         (build-exe (expand-file-name (concat "build/app" suffix) root)))
    (with-temp-buffer
      (setq buffer-file-name source)
      (setq-local my/cpp-last-executable cached)
      (cl-letf (((symbol-function 'my/project-root-or-current)
                 (lambda () root))
                ((symbol-function 'file-regular-p) (lambda (_file) t))
                ((symbol-function 'file-executable-p) (lambda (_file) t))
                ((symbol-function 'file-expand-wildcards)
                 (lambda (&rest _arguments) (list build-exe))))
        (should (equal (my/cpp--debug-executable-candidates)
                       (list cached source-exe default-exe build-exe)))))))

(ert-deftest my/cmake-preset-map-exposes-configure-build-and-test ()
  (should (eq (lookup-key my/cmake-preset-map (kbd "c"))
              #'my/cmake-configure-preset))
  (should (eq (lookup-key my/cmake-preset-map (kbd "b"))
              #'my/cmake-build-preset))
  (should (eq (lookup-key my/cmake-preset-map (kbd "t"))
              #'my/cmake-test-preset)))

(provide 'init-cpp-test)
;;; init-cpp-test.el ends here
