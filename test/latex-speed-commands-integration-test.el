;;; latex-speed-commands-integration-test.el --- Integration tests for latex-speed-commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Blaine Mooers

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Integration tests.  They drive the real Emacs command loop with
;; `execute-kbd-macro', and they check the interaction with AUCTeX.
;; Every test carries the tag `integration', so
;;
;;   make test-integration
;;
;; runs only these.  The AUCTeX tests run only when AUCTeX can be
;; loaded.  `make install-test-deps' fetches a copy into .deps/auctex,
;; and AUCTEX_DIR points the Makefile at any other checkout.
;; Without AUCTeX, those tests are skipped.

;;; Code:

(require 'ert)
(require 'latex-speed-commands-test-helper)

(defvar TeX-parse-self)
(defvar TeX-auto-save)
(declare-function LaTeX-mode "latex" ())

(defun lsc-auctex-test-available-p ()
  "Return non-nil when AUCTeX can be loaded."
  (and (require 'tex-site nil t)
       (require 'tex nil t)
       (require 'latex nil t)
       (require 'font-latex nil t)
       (fboundp 'TeX-insert-dollar)))


;;;; AUCTeX

(defmacro lsc-auctex-test-with-buffer (content &rest body)
  "Run BODY in an AUCTeX `LaTeX-mode' buffer with CONTENT."
  (declare (indent 1) (debug t))
  `(progn
     (skip-unless (lsc-auctex-test-available-p))
     (let ((TeX-parse-self nil) (TeX-auto-save nil))
       (with-temp-buffer
         (insert ,content)
         (LaTeX-mode)
         (latex-speed-commands-mode 1)
         (save-window-excursion
           (switch-to-buffer (current-buffer))
           (goto-char (point-min))
           ,@body)))))

(ert-deftest lsc-integration-test-auctex-detected ()
  :tags '(integration)
  (lsc-auctex-test-with-buffer lsc-test-document
    (should (bound-and-true-p TeX-mode-p))))

(ert-deftest lsc-integration-test-auctex-electric-dollar-survives ()
  :tags '(integration)
  (lsc-auctex-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (should (eq (key-binding "$") 'TeX-insert-dollar))
    (should (eq (key-binding "n") 'latex-speed-commands-dispatch))))

(ert-deftest lsc-integration-test-auctex-navigation-and-folding ()
  :tags '(integration)
  (lsc-auctex-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (execute-kbd-macro "nn")
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (lsc-test-goto "\\section{Alpha}")
    (execute-kbd-macro "c")
    (forward-line 1)
    (should (outline-invisible-p (point)))))

(ert-deftest lsc-integration-test-auctex-environment-names ()
  :tags '(integration)
  (lsc-auctex-test-with-buffer lsc-test-document
    (should (member "itemize" (latex-speed-commands--environment-names)))))

;;;; Real command loop

(ert-deftest lsc-integration-test-real-command-loop ()
  "Keys typed through the command loop reach the speed commands."
  :tags '(integration)
  (lsc-test-with-buffer lsc-test-document
    (save-window-excursion
      (switch-to-buffer (current-buffer))
      (lsc-test-goto "\\section{Alpha}")
      (execute-kbd-macro "nn")
      (should (equal (lsc-test-line) "\\section{Beta}"))
      (lsc-test-goto "Alpha text")
      (execute-kbd-macro "nx")
      (should (equal (lsc-test-line) "nxAlpha text."))
      (lsc-test-goto "\\section{Beta}")
      (execute-kbd-macro "F*")
      (should (equal (lsc-test-line) "\\begin{equation*}")))))


(provide 'latex-speed-commands-integration-test)
;;; latex-speed-commands-integration-test.el ends here
