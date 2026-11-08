;;; latex-speed-commands-test.el --- Tests for latex-speed-commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Blaine Mooers

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Unit tests for latex-speed-commands.el.  Each test works on a
;; temporary `latex-mode' buffer built by `lsc-test-with-buffer' from
;; latex-speed-commands-test-helper.el.  Run them with
;;
;;   make test-unit
;;
;; or from Emacs with M-x ert RET t RET after loading this file.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'latex-speed-commands-test-helper)

;;;; Activation

(ert-deftest lsc-test-heading-detection ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (should (latex-speed-commands-at-heading-p))
    (forward-char 1)
    (should-not (latex-speed-commands-at-heading-p))
    (lsc-test-goto "Alpha text")
    (should-not (latex-speed-commands-at-heading-p))))

(ert-deftest lsc-test-heading-variants ()
  (dolist (line '("\\section{A}" "\\section*{A}" "\\section[Short]{Long}"
                  "  \\subsection{Indented}" "% \\section{Commented}"
                  "\\paragraph {Spaced}"))
    (lsc-test-with-buffer (concat line "\n")
      (should (latex-speed-commands-at-heading-p))))
  (dolist (line '("\\sectionmark{A}" "text \\section{A}" "\\sections"))
    (lsc-test-with-buffer (concat line "\n")
      (should-not (latex-speed-commands-at-heading-p)))))

(ert-deftest lsc-test-environment-line-detection ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\begin{equation}")
    (should (latex-speed-commands-at-environment-line-p))
    (lsc-test-goto "\\end{equation}")
    (should (latex-speed-commands-at-environment-line-p))
    (lsc-test-goto "E = mc")
    (should-not (latex-speed-commands-at-environment-line-p))))

(ert-deftest lsc-test-binding-at-heading ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (should (eq (key-binding "n") 'latex-speed-commands-dispatch))
    (should (eq (key-binding "?") 'latex-speed-commands-dispatch))
    (should (eq (key-binding " ") 'latex-speed-commands-dispatch))))

(ert-deftest lsc-test-binding-falls-through ()
  (lsc-test-with-buffer lsc-test-document
    ;; In the body text.
    (lsc-test-goto "Alpha text")
    (should (eq (key-binding "n") 'self-insert-command))
    ;; In the middle of a heading line.
    (lsc-test-goto "\\section{Alpha}")
    (forward-char 3)
    (should (eq (key-binding "n") 'self-insert-command))
    ;; A key that has no speed command at a heading.
    (lsc-test-goto "\\section{Alpha}")
    (should-not (eq (key-binding "z") 'latex-speed-commands-dispatch))))

(ert-deftest lsc-test-major-mode-bindings-survive ()
  "Keys without a speed command keep the binding of the major mode.
This is what keeps the electric keys of AUCTeX working."
  (lsc-test-with-buffer lsc-test-document
    (let ((map (make-sparse-keymap)))
      (define-key map "$" #'ignore)
      (use-local-map map))
    (lsc-test-goto "\\section{Alpha}")
    (should (eq (key-binding "$") 'ignore))))

(ert-deftest lsc-test-typing-in-body-inserts ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "Alpha text")
    (lsc-test-press "n")
    (should (equal (lsc-test-line) "nAlpha text."))))

(ert-deftest lsc-test-mode-off-or-use-nil ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (let ((latex-speed-commands-use nil))
      (should (eq (key-binding "n") 'self-insert-command)))
    (latex-speed-commands-mode -1)
    (should (eq (key-binding "n") 'self-insert-command))))

(ert-deftest lsc-test-use-function-activates-at-bol ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "Alpha text")
    (let ((latex-speed-commands-use #'bolp))
      (should (eq (key-binding "n") 'latex-speed-commands-dispatch))
      (lsc-test-press "n")
      (should (equal (lsc-test-line) "\\subsection{Alpha One}")))))

(ert-deftest lsc-test-user-entry-overrides ()
  (lsc-test-with-buffer lsc-test-document
    (let* ((called nil)
           (latex-speed-commands
            (cons (cons "n" (lambda () (interactive) (setq called t)))
                  latex-speed-commands)))
      (lsc-test-goto "\\section{Alpha}")
      (lsc-test-press "n")
      (should called))))

(ert-deftest lsc-test-sexp-and-function-entries ()
  (lsc-test-with-buffer lsc-test-document
    (setq lsc-test-log nil)
    (let ((latex-speed-commands
           (append (list (cons "y" '(push 'sexp lsc-test-log))
                         (cons "z" (lambda () (push 'fn lsc-test-log))))
                   latex-speed-commands)))
      (lsc-test-goto "\\section{Alpha}")
      (lsc-test-press "y")
      (lsc-test-press "z")
      (should (equal lsc-test-log '(fn sexp))))))

(ert-deftest lsc-test-environment-commands-take-priority ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\begin{equation}")
    (let ((latex-speed-commands-use #'bolp))
      ;; The environment `n' looks for the next \begin, and there is
      ;; none, so it signals an error and point stays.  The heading
      ;; `n' would have moved to the next chapter.
      (should-error (lsc-test-press "n") :type 'user-error)
      (should (equal (lsc-test-line) "\\begin{equation}")))))


;;;; Navigation

(ert-deftest lsc-test-next-previous-heading ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "n")
    (should (equal (lsc-test-line) "\\subsection{Alpha One}"))
    (lsc-test-press "n")
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (lsc-test-press "p")
    (lsc-test-press "p")
    (should (equal (lsc-test-line) "\\section{Alpha}"))))

(ert-deftest lsc-test-move-safe-restores-point ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\chapter{Methods}")
    (let ((pos (point)))
      (should-error (lsc-test-press "n") :type 'user-error)
      (should (= (point) pos)))))

(ert-deftest lsc-test-same-level ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "f")
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (should-error (lsc-test-press "f") :type 'user-error)
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (lsc-test-press "b")
    (should (equal (lsc-test-line) "\\section{Alpha}"))
    (should-error (lsc-test-press "b") :type 'user-error)
    (lsc-test-goto "\\chapter{Introduction}")
    (lsc-test-press "f")
    (should (equal (lsc-test-line) "\\chapter{Methods}"))))

(ert-deftest lsc-test-up-heading ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\subsection{Alpha One}")
    (lsc-test-press "u")
    (should (equal (lsc-test-line) "\\section{Alpha}"))
    (lsc-test-press "u")
    (should (equal (lsc-test-line) "\\chapter{Introduction}"))
    (should-error (lsc-test-press "u") :type 'user-error)))

(ert-deftest lsc-test-heading-to-environment ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Beta}")
    (lsc-test-press "F")
    (should (equal (lsc-test-line) "\\begin{equation}"))
    (lsc-test-goto "\\chapter{Methods}")
    (lsc-test-press "B")
    (should (equal (lsc-test-line) "\\begin{equation}"))))


;;;; Sections

(ert-deftest lsc-test-section-bounds ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (pcase-let ((`(,beg ,end ,level) (latex-speed-commands--section-bounds)))
      (should (= level 2))
      (should (equal (buffer-substring beg end)
                     "\\section{Alpha}\nAlpha text.\n\\subsection{Alpha One}\nA1 text.\n")))
    (lsc-test-goto "\\chapter{Methods}")
    (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
      (should (equal (buffer-substring beg end)
                     "\\chapter{Methods}\nMethods text.\n")))))

(ert-deftest lsc-test-section-stops-at-boundaries ()
  (lsc-test-with-buffer "\\chapter{One}\nText.\n\\appendix\n\\chapter{A}\n"
    (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
      (should (equal (buffer-substring beg end) "\\chapter{One}\nText.\n")))))

(ert-deftest lsc-test-before-first-heading ()
  (lsc-test-with-buffer lsc-test-document
    (should-error (latex-speed-commands-kill-section) :type 'user-error)))

(ert-deftest lsc-test-kill-and-yank-section ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "k")
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (should-not (string-match-p "Alpha" (buffer-string)))
    (should (string-prefix-p "\\section{Alpha}" (current-kill 0)))))

(ert-deftest lsc-test-copy-section ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Beta}")
    (let ((before (buffer-string)))
      (lsc-test-press "w")
      (should (equal before (buffer-string)))
      (should (string-prefix-p "\\section{Beta}\nBeta text." (current-kill 0))))))

(ert-deftest lsc-test-mark-section ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (transient-mark-mode 1)
    (lsc-test-press "@")
    (should (region-active-p))
    (should (equal (buffer-substring (region-beginning) (region-end))
                   "\\section{Alpha}\nAlpha text.\n\\subsection{Alpha One}\nA1 text.\n"))))

(ert-deftest lsc-test-narrow-toggle ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Beta}")
    (lsc-test-press "s")
    (should (buffer-narrowed-p))
    (should (string-prefix-p "\\section{Beta}" (buffer-string)))
    (should-not (string-match-p "Methods" (buffer-string)))
    (goto-char (point-min))
    (lsc-test-press "s")
    (should-not (buffer-narrowed-p))))

(ert-deftest lsc-test-count-words ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\chapter{Methods}")
    (should (= (latex-speed-commands-count-words-section) 4))))

(ert-deftest lsc-test-move-section-up-down ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Beta}")
    (lsc-test-press "U")
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (should (< (save-excursion (search-forward "{Beta}" nil t))
               (save-excursion (goto-char (point-min))
                               (search-forward "{Alpha}" nil t))))
    ;; The subsection travels with Alpha.
    (should (string-match-p "\\\\section{Alpha}\nAlpha text.\n\\\\subsection{Alpha One}"
                            (buffer-string)))
    (should-error (lsc-test-press "U") :type 'user-error)
    (lsc-test-press "D")
    (should (equal (buffer-string) lsc-test-document))
    (should (equal (lsc-test-line) "\\section{Beta}"))
    (should-error (lsc-test-press "D") :type 'user-error)))

(ert-deftest lsc-test-move-last-section-without-newline ()
  (lsc-test-with-buffer "\\section{A}\nA.\n\\section{B}\nB."
    (lsc-test-goto "\\section{B}")
    (latex-speed-commands-move-section-up)
    (should (string-prefix-p "\\section{B}\nB.\n\\section{A}\nA." (buffer-string)))))

(ert-deftest lsc-test-promote-demote-heading ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "r")
    (should (equal (lsc-test-line) "\\subsection{Alpha}"))
    (lsc-test-press "l")
    (lsc-test-press "l")
    (should (equal (lsc-test-line) "\\chapter{Alpha}"))
    ;; Only the heading line changes.
    (should (string-match-p "\\\\subsection{Alpha One}" (buffer-string)))))

(ert-deftest lsc-test-demote-section ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "R")
    (should (equal (lsc-test-line) "\\subsection{Alpha}"))
    (should (string-match-p "\\\\subsubsection{Alpha One}" (buffer-string)))
    (lsc-test-press "L")
    (should (equal (buffer-string) lsc-test-document))))

(ert-deftest lsc-test-promote-limit-is-atomic ()
  (lsc-test-with-buffer "\\part{P}\n\\chapter{C}\n"
    (let ((before (buffer-string)))
      (should-error (latex-speed-commands-promote-section) :type 'user-error)
      (should (equal before (buffer-string))))))

(ert-deftest lsc-test-insert-heading-respect-content ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "i")
    (insert "Gamma")
    (should (equal (lsc-test-line) "\\section{Gamma}"))
    (should (string-match-p
             "A1 text.\n\n\\\\section{Gamma}\n\n\\\\section{Beta}"
             (buffer-string)))))

(ert-deftest lsc-test-toggle-comment-section ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "#")
    (should (equal (lsc-test-line) "% \\section{Alpha}"))
    (should (string-match-p "% A1 text." (buffer-string)))
    (should (string-match-p "^\\\\section{Beta}" (buffer-string)))
    ;; Still a speed position, so the same key uncomments.
    (should (latex-speed-commands-at-heading-p))
    (lsc-test-press "#")
    (should (equal (buffer-string) lsc-test-document))))

(ert-deftest lsc-test-toggle-heading-star ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Beta}")
    (lsc-test-press "*")
    (should (equal (lsc-test-line) "\\section*{Beta}"))
    (lsc-test-press "*")
    (should (equal (lsc-test-line) "\\section{Beta}"))))

(ert-deftest lsc-test-section-label-new-and-edit ()
  (lsc-test-with-buffer "\\section{Results and \\emph{Discussion}}\nText.\n"
    (cl-letf (((symbol-function 'read-string)
               (lambda (_prompt initial &rest _) initial)))
      (lsc-test-press ":"))
    (should (equal (buffer-string)
                   "\\section{Results and \\emph{Discussion}}\n\\label{sec:results-and-discussion}\nText.\n"))
    (goto-char (point-min))
    (latex-speed-commands-set-section-label "sec:new")
    (should (equal (buffer-string)
                   "\\section{Results and \\emph{Discussion}}\n\\label{sec:new}\nText.\n"))))

(ert-deftest lsc-test-label-on-same-line ()
  (lsc-test-with-buffer "\\chapter[Short]{Long Title}\\label{chap:old}\n"
    (latex-speed-commands-set-section-label "chap:fresh")
    (should (equal (buffer-string)
                   "\\chapter[Short]{Long Title}\\label{chap:fresh}\n"))))

(ert-deftest lsc-test-outline-path ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "A1 text")
    (should (equal (latex-speed-commands--outline-path)
                   '("Introduction" "Alpha" "Alpha One")))))

(ert-deftest lsc-test-insert-environment-fallback ()
  (lsc-test-with-buffer "\\section{A}\n\\label{sec:a}\nText.\n"
    (cl-letf (((symbol-function 'latex-insert-block)
               (lambda () (interactive) (insert "BLOCK"))))
      (lsc-test-press "e"))
    (should (equal (buffer-string)
                   "\\section{A}\n\\label{sec:a}\nBLOCK\nText.\n"))))

(ert-deftest lsc-test-cycle-folds-section ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (lsc-test-press "c")
    (should outline-minor-mode)
    (forward-line 1)
    (should (outline-invisible-p (point)))))


;;;; Environments

(ert-deftest lsc-test-goto-matching ()
  (lsc-test-with-buffer lsc-test-env-document
    (lsc-test-goto "\\begin{itemize}")
    (lsc-test-press "e")
    (should (equal (lsc-test-line) "\\end{itemize}"))
    (lsc-test-press "e")
    (should (equal (lsc-test-line) "\\begin{itemize}"))))

(ert-deftest lsc-test-environment-navigation ()
  (lsc-test-with-buffer lsc-test-env-document
    (lsc-test-press "n")
    (should (equal (lsc-test-line) "\\begin{itemize}"))
    (lsc-test-press "n")
    (should (equal (lsc-test-line) "  \\begin{enumerate}"))
    (lsc-test-press "u")
    (should (equal (lsc-test-line) "\\begin{itemize}"))
    (lsc-test-press "p")
    (should (equal (lsc-test-line) "\\begin{figure}"))
    (should-error (lsc-test-press "u") :type 'user-error)))

(ert-deftest lsc-test-change-environment ()
  (lsc-test-with-buffer lsc-test-env-document
    (lsc-test-goto "\\end{itemize}")
    (latex-speed-commands-change-environment "description")
    (should (string-match-p "^\\\\begin{description}" (buffer-string)))
    (should (string-match-p "^\\\\end{description}" (buffer-string)))
    (should (string-match-p "\\\\begin{enumerate}" (buffer-string)))))

(ert-deftest lsc-test-toggle-environment-star ()
  (lsc-test-with-buffer "\\begin{equation}\n  x\n\\end{equation}\n"
    (lsc-test-press "*")
    (should (equal (buffer-string) "\\begin{equation*}\n  x\n\\end{equation*}\n"))
    (lsc-test-press "*")
    (should (equal (buffer-string) "\\begin{equation}\n  x\n\\end{equation}\n"))))

(ert-deftest lsc-test-kill-environment ()
  (lsc-test-with-buffer lsc-test-env-document
    (lsc-test-goto "\\begin{itemize}")
    (lsc-test-press "k")
    (should (equal (buffer-string)
                   (substring lsc-test-env-document 0
                              (string-match "\\\\begin{itemize}"
                                            lsc-test-env-document))))))

(ert-deftest lsc-test-toggle-comment-environment ()
  (lsc-test-with-buffer lsc-test-env-document
    (lsc-test-goto "\\begin{itemize}")
    (lsc-test-press "#")
    (should (equal (lsc-test-line) "% \\begin{itemize}"))
    (should (latex-speed-commands-at-environment-line-p))
    (lsc-test-press "e")
    (should (equal (lsc-test-line) "% \\end{itemize}"))
    (lsc-test-press "#")
    (should (equal (buffer-string) lsc-test-env-document))))

(ert-deftest lsc-test-environment-label-after-caption ()
  (lsc-test-with-buffer lsc-test-env-document
    (cl-letf (((symbol-function 'read-string)
               (lambda (_prompt initial &rest _) initial)))
      (lsc-test-press ":"))
    (should (string-match-p
             "\\\\caption{Growth of \\\\textit{E. coli}}\n *\\\\label{fig:growth-of-e-coli}\n\\\\end{figure}"
             (buffer-string)))
    ;; A second call edits the label instead of adding another.
    (goto-char (point-min))
    (latex-speed-commands-set-environment-label "fig:x")
    (should (= 1 (how-many "\\\\label" (point-min) (point-max))))
    (should (string-match-p "\\\\label{fig:x}" (buffer-string)))))

(ert-deftest lsc-test-environment-mark-and-narrow ()
  (lsc-test-with-buffer lsc-test-env-document
    (lsc-test-goto "  \\begin{enumerate}")
    (lsc-test-press "@")
    (should (equal (buffer-substring (region-beginning) (region-end))
                   "  \\begin{enumerate}\n    \\item Nested\n  \\end{enumerate}\n"))
    (deactivate-mark)
    (lsc-test-goto "  \\begin{enumerate}")
    (lsc-test-press "s")
    (should (equal (buffer-string)
                   "  \\begin{enumerate}\n    \\item Nested\n  \\end{enumerate}\n"))
    (lsc-test-press "s")
    (should-not (buffer-narrowed-p))))

(ert-deftest lsc-test-back-to-heading-from-environment ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\end{equation}")
    (lsc-test-press "h")
    (should (equal (lsc-test-line) "\\section{Beta}"))))

(ert-deftest lsc-test-unbalanced-environment ()
  (lsc-test-with-buffer "\\begin{itemize}\n\\item x\n"
    (should-error (latex-speed-commands-goto-matching) :type 'user-error)))


;;;; Edge cases and error paths

(ert-deftest lsc-test-title-with-braces-in-optional-argument ()
  (lsc-test-with-buffer "\\section[Short {x}]{Long Title}\n"
    (should (equal (car (latex-speed-commands--heading-title (point-min)))
                   "Long Title"))))

(ert-deftest lsc-test-execute-invalid-command ()
  (should-error (latex-speed-commands--execute 42) :type 'error))

(ert-deftest lsc-test-dispatch-without-command-self-inserts ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "Alpha text")
    (let ((last-command-event ?q))
      (latex-speed-commands-dispatch))
    (should (equal (lsc-test-line) "qAlpha text."))))

(ert-deftest lsc-test-move-safe-restores-point-after-error ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (let ((pos (point)))
      (should-error (latex-speed-commands-move-safe
                     (lambda () (interactive) (forward-line 1) (error "Boom"))))
      (should (= (point) pos)))))

(ert-deftest lsc-test-previous-heading-at-first-heading ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\chapter{Introduction}")
    (let ((pos (point)))
      (should-error (latex-speed-commands-previous-heading) :type 'user-error)
      (should (= (point) pos)))))

(ert-deftest lsc-test-backward-same-level-from-body ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "Beta text")
    (latex-speed-commands-backward-same-level)
    (should (equal (lsc-test-line) "\\section{Beta}"))))

(ert-deftest lsc-test-cycle-buffer ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\chapter{Introduction}")
    (lsc-test-press "C")
    (should outline-minor-mode)
    (lsc-test-goto "Intro text")
    (should (outline-invisible-p (point)))))

(ert-deftest lsc-test-display-outline-path-message ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "A1 text")
    (should (equal (latex-speed-commands-display-outline-path)
                   "Introduction / Alpha / Alpha One"))
    (goto-char (point-min))
    (should (equal (latex-speed-commands-display-outline-path) "Top level"))))

(ert-deftest lsc-test-insert-heading-at-end-of-buffer ()
  (lsc-test-with-buffer "\\section{A}\nText."
    (latex-speed-commands-insert-heading-respect-content)
    (should (equal (buffer-string) "\\section{A}\nText.\n\n\\section{}\n\n"))))

(ert-deftest lsc-test-heading-without-title ()
  (lsc-test-with-buffer "\\section[Only optional]\nText.\n"
    (should (latex-speed-commands-at-heading-p))
    (latex-speed-commands-set-section-label "sec:x")
    (should (string-match-p "\\\\label{sec:x}" (buffer-string)))
    (should (= (latex-speed-commands--heading-preamble-end)
               (save-excursion (goto-char (point-min))
                               (forward-line 1)
                               (line-end-position))))))

(ert-deftest lsc-test-insert-environment-without-tex-mode-helpers ()
  (lsc-test-with-buffer "\\section{A}\nText.\n"
    (cl-letf (((symbol-function 'latex-insert-block) nil)
              ((symbol-function 'read-string) (lambda (&rest _) "quote")))
      (latex-speed-commands-insert-environment))
    (should (equal (buffer-string)
                   "\\section{A}\n\\begin{quote}\n\n\\end{quote}\nText.\n"))))

(ert-deftest lsc-test-insert-environment-uses-auctex ()
  (lsc-test-with-buffer "\\section{A}\n"
    (setq-local TeX-mode-p t)
    (cl-letf (((symbol-function 'LaTeX-environment)
               (lambda (_arg) (interactive "P") (insert "AUCTEX"))))
      (latex-speed-commands-insert-environment))
    (should (equal (buffer-string) "\\section{A}\nAUCTEX\n"))))

(ert-deftest lsc-test-environment-info-off-line ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "Beta text")
    (should-error (latex-speed-commands-kill-environment) :type 'user-error)))

(ert-deftest lsc-test-environment-at-end-of-buffer ()
  (lsc-test-with-buffer "Text.\n\\begin{center}\nx\n\\end{center}"
    (lsc-test-goto "\\begin{center}")
    (latex-speed-commands-kill-environment)
    (should (equal (buffer-string) "Text.\n"))))

(ert-deftest lsc-test-previous-environment-at-first ()
  (lsc-test-with-buffer lsc-test-env-document
    (should-error (latex-speed-commands-previous-environment) :type 'user-error)
    (should (= (point) (point-min)))))

(ert-deftest lsc-test-change-environment-prompts ()
  (lsc-test-with-buffer lsc-test-env-document
    (cl-letf (((symbol-function 'completing-read)
               (lambda (&rest _) "wrapfigure")))
      (should (equal (latex-speed-commands-change-environment) "wrapfigure")))
    (should (string-match-p "\\\\end{wrapfigure}" (buffer-string)))))

(ert-deftest lsc-test-environment-names-are-unique ()
  (let ((names (latex-speed-commands--environment-names)))
    (should (member "itemize" names))
    (should (equal names (delete-dups (copy-sequence names))))))

(ert-deftest lsc-test-environment-label-without-caption ()
  (lsc-test-with-buffer "\\begin{equation}\n  x = 1\n\\end{equation}\n"
    (latex-speed-commands-set-environment-label "eq:one")
    (should (string-match-p
             "\\`\\\\begin{equation}\n *\\\\label{eq:one}\n  x = 1\n\\\\end{equation}\n\\'"
             (buffer-string)))))

(ert-deftest lsc-test-copy-environment ()
  (lsc-test-with-buffer "\\begin{center}\nx\n\\end{center}\n"
    (latex-speed-commands-copy-environment)
    (should (equal (current-kill 0) "\\begin{center}\nx\n\\end{center}\n"))
    (should (equal (buffer-string) "\\begin{center}\nx\n\\end{center}\n"))))

(ert-deftest lsc-test-compile-and-view-dispatch ()
  (lsc-test-with-buffer lsc-test-document
    (let ((log nil))
      (cl-letf (((symbol-function 'tex-file)
                 (lambda () (interactive) (push 'tex-file log)))
                ((symbol-function 'tex-view)
                 (lambda () (interactive) (push 'tex-view log)))
                ((symbol-function 'TeX-command-master)
                 (lambda (&optional _) (interactive) (push 'TeX-command-master log)))
                ((symbol-function 'TeX-view)
                 (lambda () (interactive) (push 'TeX-view log))))
        (latex-speed-commands-compile)
        (latex-speed-commands-view)
        (setq-local TeX-mode-p t)
        (latex-speed-commands-compile)
        (latex-speed-commands-view))
      (should (equal log '(TeX-view TeX-command-master tex-view tex-file))))))

(ert-deftest lsc-test-compile-and-view-without-tools ()
  (with-temp-buffer
    (cl-letf (((symbol-function 'tex-file) nil)
              ((symbol-function 'tex-view) nil))
      (should-error (latex-speed-commands-compile) :type 'user-error)
      (should-error (latex-speed-commands-view) :type 'user-error))))

(ert-deftest lsc-test-help-requires-activation ()
  (let ((latex-speed-commands-use nil))
    (should-error (latex-speed-commands-help) :type 'user-error)))

(ert-deftest lsc-test-command-names-in-help ()
  (should (equal (latex-speed-commands--command-name 'occur) "occur"))
  (should (equal (latex-speed-commands--command-name
                  '(latex-speed-commands-move-safe 'latex-speed-commands-up-heading))
                 "latex-speed-commands-up-heading (safe)"))
  (should (equal (latex-speed-commands--command-name
                  '(latex-speed-commands-move-safe latex-speed-commands-up-heading))
                 "latex-speed-commands-up-heading (safe)"))
  (should (equal (latex-speed-commands--command-name '(message "hi"))
                 "(message \"hi\")"))
  (should (equal (latex-speed-commands--command-summary 'latex-speed-commands-kill-section)
                 "Kill the current section, including all of its subsections."))
  (should (equal (latex-speed-commands--command-summary '(message "hi")) "")))

(ert-deftest lsc-test-minibuffer-never-activates ()
  (lsc-test-with-buffer lsc-test-document
    (lsc-test-goto "\\section{Alpha}")
    (cl-letf (((symbol-function 'minibufferp) (lambda (&rest _) t)))
      (should-not (latex-speed-commands--lookup "n")))))


;;;; Help and helpers

(ert-deftest lsc-test-help-buffer ()
  (lsc-test-with-buffer lsc-test-document
    (save-window-excursion
      (latex-speed-commands-help))
    (with-current-buffer "*Help*"
      (let ((text (buffer-string)))
        (should (string-match-p "Outline Navigation" text))
        (should (string-match-p "Environment Navigation" text))
        (should (string-match-p "latex-speed-commands-next-heading (safe)" text))
        (should (string-match-p "^SPC " text))))))

(ert-deftest lsc-test-slugify ()
  (should (equal (latex-speed-commands--slugify "Results and \\emph{Discussion}")
                 "results-and-discussion"))
  (should (equal (latex-speed-commands--slugify "  A--B  ") "a-b"))
  (should (equal (latex-speed-commands--slugify nil) "")))

(ert-deftest lsc-test-label-prefix ()
  (should (equal (latex-speed-commands--label-prefix "equation*") "eq:"))
  (should (equal (latex-speed-commands--label-prefix "subsection") "sec:"))
  (should (equal (latex-speed-commands--label-prefix "myenv") "myenv:")))

(ert-deftest lsc-test-in-comment ()
  (with-temp-buffer
    (insert "text % comment\n50\\% not a comment\n")
    (should (latex-speed-commands--in-comment-p 9))
    (should-not (latex-speed-commands--in-comment-p 3))
    (goto-char (point-min))
    (forward-line 1)
    (should-not (latex-speed-commands--in-comment-p (line-end-position)))))

(ert-deftest lsc-test-custom-levels ()
  (lsc-test-with-buffer "\\section{A}\n\\frametitle{F}\n"
    (let ((latex-speed-commands-section-levels
           (append latex-speed-commands-section-levels '(("frametitle" . 7)))))
      (lsc-test-goto "\\frametitle")
      (should (latex-speed-commands-at-heading-p))
      (lsc-test-press "u")
      (should (equal (lsc-test-line) "\\section{A}")))))

(provide 'latex-speed-commands-test)
;;; latex-speed-commands-test.el ends here
