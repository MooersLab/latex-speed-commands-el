;;; latex-speed-commands-test-helper.el --- Shared fixtures for the tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Blaine Mooers

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Fixtures, a buffer macro, and small helpers shared by the unit and
;; integration test files.  When the environment variable
;; LSC_COVERAGE is set, this file also starts undercover.el so that
;; the tests measure line coverage of latex-speed-commands.el.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'tex-mode)

(defvar TeX-mode-p)

(when (and (getenv "LSC_COVERAGE") (require 'undercover nil t))
  (eval '(undercover "latex-speed-commands.el"
                     (:report-format 'lcov)
                     (:report-file "coverage.lcov")
                     (:send-report nil))
        t))

(require 'latex-speed-commands)

(defconst lsc-test-document
  "\\documentclass{book}
\\begin{document}
\\chapter{Introduction}
Intro text.
\\section{Alpha}
Alpha text.
\\subsection{Alpha One}
A1 text.
\\section{Beta}
Beta text.
\\begin{equation}
  E = mc^2
\\end{equation}
\\chapter{Methods}
Methods text.
\\end{document}
"
  "A small book used by most tests.")

(defmacro lsc-test-with-buffer (content &rest body)
  "Run BODY in a `latex-mode' buffer with CONTENT and speed commands on.
Point starts at the beginning of the buffer."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (insert ,content)
     (let ((latex-mode-hook nil)
           (tex-mode-hook nil)
           (text-mode-hook nil))
       (latex-mode))
     (latex-speed-commands-mode 1)
     (goto-char (point-min))
     ,@body))

(defun lsc-test-goto (string)
  "Move to the beginning of the first line that starts with STRING.\nLeading whitespace in the line and in STRING is ignored."
  (goto-char (point-min))
  (re-search-forward (concat "^[ \t]*" (regexp-quote (string-trim-left string))))
  (beginning-of-line))

(defun lsc-test-line ()
  "Return the text of the current line."
  (buffer-substring-no-properties (line-beginning-position)
                                  (line-end-position)))

(defun lsc-test-press (key)
  "Simulate typing the one-character string KEY."
  (let* ((last-command-event (aref key 0))
         (cmd (key-binding key)))
    (setq this-command cmd)
    (call-interactively cmd)))


(defconst lsc-test-env-document
  "\\begin{figure}
  \\centering
  \\includegraphics{x}
  \\caption{Growth of \\textit{E. coli}}
\\end{figure}
\\begin{itemize}
  \\item One % \\end{itemize} in a comment
  \\begin{enumerate}
    \\item Nested
  \\end{enumerate}
\\end{itemize}
"
  "Environments used by the environment tests.")

(defvar lsc-test-log nil
  "Record of calls made by test speed commands.")

(provide 'latex-speed-commands-test-helper)
;;; latex-speed-commands-test-helper.el ends here
