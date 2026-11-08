;;; latex-speed-commands.el --- Org-style speed commands for LaTeX -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Blaine Mooers

;; Author: Blaine Mooers <blaine-mooers@ou.edu>
;; Maintainer: Blaine Mooers <blaine-mooers@ou.edu>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: tex, outlines, convenience
;; URL: https://github.com/MooersLab/latex-speed-commands-el
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package brings the single-key "speed commands" of Org mode to
;; LaTeX buffers.  In Org, when point is at the very beginning of a
;; headline, pressing a plain key such as `n', `p', `c' or `k' runs an
;; outline command instead of inserting the character.  The same
;; happens at the beginning of a source block line.  This package does
;; the same for LaTeX.
;;
;;   * At the beginning of a sectioning line such as \section{...},
;;     the keys in `latex-speed-commands' are active.  This is the
;;     analog of an Org headline.
;;
;;   * At the beginning of a \begin{...} or \end{...} line, the keys in
;;     `latex-speed-commands-environment' are active.  This is the
;;     analog of the Babel speed keys on a #+begin_src line.
;;
;;   * Everywhere else, and for every key that is not listed, typing
;;     behaves exactly as before.  AUCTeX bindings such as the electric
;;     `$' keep working because the package never shadows a key that
;;     it does not use at the current position.
;;
;; The key choices follow `org-speed-commands' as closely as LaTeX
;; allows, so muscle memory carries over between the two kinds of
;; documents.  Press `?' at a heading to list all speed commands.
;;
;; Quick start:
;;
;;   (require 'latex-speed-commands)
;;   (add-hook 'LaTeX-mode-hook #'latex-speed-commands-mode) ; AUCTeX
;;   (add-hook 'latex-mode-hook #'latex-speed-commands-mode) ; built-in
;;
;; Like `org-use-speed-commands', the option `latex-speed-commands-use'
;; may be a function.  Setting it to `bolp' activates the heading speed
;; keys at the beginning of every line, which is what some people mean
;; by "speed keys in the leftmost column".
;;
;; See the Info manual (info "(latex-speed-commands)") and README.md
;; for the full key tables.

;;; Code:

(require 'cl-lib)
(require 'outline)
(require 'subr-x)

(declare-function TeX-command-master "tex" (&optional override-confirm))
(declare-function TeX-view "tex" ())
(declare-function LaTeX-environment "latex" (arg))
(declare-function LaTeX-environment-list "latex" ())
(declare-function tex-file "tex-mode" ())
(declare-function tex-view "tex-mode" ())
(declare-function latex-insert-block "tex-mode")
(defvar latex-standard-block-names)
(defvar TeX-mode-p)
(defvar latex-speed-commands-mode)


;;;; Customization

(defgroup latex-speed-commands nil
  "Single-key speed commands for LaTeX, modeled on Org speed commands."
  :group 'tex
  :prefix "latex-speed-commands-"
  :link '(url-link :tag "Home page"
                   "https://github.com/MooersLab/latex-speed-commands-el")
  :link '(info-link "(latex-speed-commands)"))

(defcustom latex-speed-commands-use t
  "Non-nil means activate single-key speed commands in LaTeX buffers.
This is the analog of `org-use-speed-commands'.

When the value is t, the commands in `latex-speed-commands' are
active when point is at the beginning of a sectioning line such as
\\section{...}, and the commands in `latex-speed-commands-environment'
are active when point is at the beginning of a \\begin{...} or
\\end{...} line.

When the value is a function, it is called with no arguments.  If
it returns non-nil, the commands in `latex-speed-commands' are also
active at the current position.  For example, the value `bolp'
activates them at the beginning of every line.

When the value is nil, no speed command is ever active.  The minor
mode `latex-speed-commands-mode' must be on in either case."
  :type '(choice (const :tag "Never" nil)
                 (const :tag "At headings and environment lines" t)
                 (function :tag "Also where this function returns non-nil"))
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands-section-levels
  '(("part" . 0)
    ("chapter" . 1)
    ("section" . 2)
    ("subsection" . 3)
    ("subsubsection" . 4)
    ("paragraph" . 5)
    ("subparagraph" . 6))
  "Alist of LaTeX sectioning commands and their outline levels.
Each element has the form (NAME . LEVEL) where NAME is the command
name without the backslash.  A smaller LEVEL is a higher rank.  A
line that starts with one of these commands, optionally starred and
followed by an optional argument or a brace, is a heading.
Promotion and demotion move between neighboring entries of this
alist after sorting it by LEVEL."
  :type '(alist :key-type (string :tag "Command")
                :value-type (integer :tag "Level"))
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands-section-boundary-regexp
  (concat "^[ \t]*\\\\\\(?:"
          "end[ \t]*{document}"
          "\\|appendix\\b"
          "\\|frontmatter\\b"
          "\\|mainmatter\\b"
          "\\|backmatter\\b"
          "\\|bibliography{"
          "\\|printbibliography\\b"
          "\\)")
  "Regexp for lines that end every section that precedes them.
A section normally extends up to the next heading of the same or a
higher rank.  A line that matches this regexp also ends it, so that
commands such as `latex-speed-commands-kill-section' never swallow
\\end{document} or the bibliography.  The regexp must not contain
capturing groups."
  :type 'regexp
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands-label-prefixes
  '(("part" . "part:")
    ("chapter" . "chap:")
    ("section" . "sec:")
    ("subsection" . "sec:")
    ("subsubsection" . "sec:")
    ("paragraph" . "par:")
    ("subparagraph" . "par:")
    ("equation" . "eq:")
    ("align" . "eq:")
    ("gather" . "eq:")
    ("multline" . "eq:")
    ("figure" . "fig:")
    ("table" . "tab:")
    ("listing" . "lst:")
    ("theorem" . "thm:")
    ("lemma" . "lem:")
    ("proposition" . "prop:")
    ("corollary" . "cor:")
    ("definition" . "def:"))
  "Alist of heading or environment names and their label prefixes.
The label commands propose a label made of this prefix and a slug
of the title or caption.  A name that is not listed uses its own
name followed by a colon.  Starred names use the entry of the
unstarred name."
  :type '(alist :key-type (string :tag "Name")
                :value-type (string :tag "Prefix"))
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands-lighter " Speed"
  "Mode line lighter for `latex-speed-commands-mode'."
  :type '(choice (const :tag "None" nil) string)
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands
  '(("Outline Navigation")
    ("n" . (latex-speed-commands-move-safe 'latex-speed-commands-next-heading))
    ("p" . (latex-speed-commands-move-safe 'latex-speed-commands-previous-heading))
    ("f" . (latex-speed-commands-move-safe 'latex-speed-commands-forward-same-level))
    ("b" . (latex-speed-commands-move-safe 'latex-speed-commands-backward-same-level))
    ("F" . latex-speed-commands-next-environment)
    ("B" . latex-speed-commands-previous-environment)
    ("u" . (latex-speed-commands-move-safe 'latex-speed-commands-up-heading))
    ("j" . imenu)
    ("Outline Visibility")
    ("c" . latex-speed-commands-cycle)
    ("C" . latex-speed-commands-cycle-buffer)
    (" " . latex-speed-commands-display-outline-path)
    ("s" . latex-speed-commands-toggle-narrow-to-section)
    ("k" . latex-speed-commands-kill-section)
    ("w" . latex-speed-commands-copy-section)
    ("=" . latex-speed-commands-count-words-section)
    ("Outline Structure Editing")
    ("U" . latex-speed-commands-move-section-up)
    ("D" . latex-speed-commands-move-section-down)
    ("r" . latex-speed-commands-demote-heading)
    ("l" . latex-speed-commands-promote-heading)
    ("R" . latex-speed-commands-demote-section)
    ("L" . latex-speed-commands-promote-section)
    ("i" . latex-speed-commands-insert-heading-respect-content)
    ("@" . latex-speed-commands-mark-section)
    ("#" . latex-speed-commands-toggle-comment-section)
    ("Heading Editing")
    ("*" . latex-speed-commands-toggle-heading-star)
    (":" . latex-speed-commands-set-section-label)
    ("e" . latex-speed-commands-insert-environment)
    ("Compile and View")
    ("x" . latex-speed-commands-compile)
    ("v" . latex-speed-commands-view)
    ("Misc")
    ("/" . occur)
    ("?" . latex-speed-commands-help))
  "Alist of speed commands for LaTeX heading lines.
This is the analog of `org-speed-commands'.

The car of each entry is a string with a single letter, which must
be assigned to `self-insert-command' in the global map.

The cdr is either a command to be called interactively, a function
to be called, or a form to be evaluated.

An entry that is just a list with a single string will be
interpreted as a descriptive headline that will be added when
listing the speed commands in the Help buffer using the `?' speed
command.

To add a command of your own, push it onto the front of this list,
because the first matching entry wins."
  :type '(repeat :value ("k" . ignore)
                 (choice :value ("k" . ignore)
                         (list :tag "Descriptive Headline"
                               (string :tag "Headline"))
                         (cons :tag "Letter and Command"
                               (string :tag "Command letter")
                               (choice (function) (sexp)))))
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands-environment
  '(("Environment Navigation")
    ("n" . latex-speed-commands-next-environment)
    ("p" . latex-speed-commands-previous-environment)
    ("e" . latex-speed-commands-goto-matching)
    ("u" . latex-speed-commands-up-environment)
    ("h" . latex-speed-commands-back-to-heading)
    ("Environment Editing")
    ("c" . latex-speed-commands-change-environment)
    ("*" . latex-speed-commands-toggle-environment-star)
    (":" . latex-speed-commands-set-environment-label)
    ("s" . latex-speed-commands-toggle-narrow-to-environment)
    ("k" . latex-speed-commands-kill-environment)
    ("w" . latex-speed-commands-copy-environment)
    ("@" . latex-speed-commands-mark-environment)
    ("#" . latex-speed-commands-toggle-comment-environment)
    ("Compile and View")
    ("x" . latex-speed-commands-compile)
    ("v" . latex-speed-commands-view)
    ("Misc")
    ("/" . occur)
    ("?" . latex-speed-commands-help))
  "Alist of speed commands for \\begin and \\end lines.
This plays the role that the Babel speed keys play on an Org source
block line.  The format is the same as for `latex-speed-commands'."
  :type '(repeat :value ("k" . ignore)
                 (choice :value ("k" . ignore)
                         (list :tag "Descriptive Headline"
                               (string :tag "Headline"))
                         (cons :tag "Letter and Command"
                               (string :tag "Command letter")
                               (choice (function) (sexp)))))
  :package-version '(latex-speed-commands . "0.1.0"))

(defcustom latex-speed-commands-activate-functions
  '(latex-speed-commands-environment-activate
    latex-speed-commands-heading-activate)
  "Abnormal hook that decides which speed command, if any, to run.
This is the analog of `org-speed-command-hook'.  Each function is
called with one argument, the key as a one-character string.  The
first non-nil return value is the speed command to execute.  A nil
value from every function means that the key keeps its normal
binding."
  :type 'hook
  :package-version '(latex-speed-commands . "0.1.0"))


;;;; Regexps and low-level parsing

(defconst latex-speed-commands--environment-line-regexp
  "^\\([ \t]*\\)\\(%+[ \t]*\\)?\\\\\\(begin\\|end\\)[ \t]*{\\([^}\n]+\\)}"
  "Regexp for a line that starts with \\begin{NAME} or \\end{NAME}.
Group 1 is the indentation, group 2 an optional comment prefix,
group 3 the word begin or end, and group 4 the environment name.")

(defconst latex-speed-commands--environment-token-regexp
  "\\\\\\(begin\\|end\\)[ \t]*{\\([^}\n]*\\)}"
  "Regexp for any \\begin{NAME} or \\end{NAME} token.")

(defvar latex-speed-commands--heading-regexp-cache nil
  "Cons of the levels alist and the heading regexp built from it.")

(defun latex-speed-commands--heading-regexp ()
  "Return the regexp that matches a heading line.
Group 1 is the indentation, group 2 an optional comment prefix,
group 3 the command name, and group 4 the optional star."
  (unless (equal (car latex-speed-commands--heading-regexp-cache)
                 latex-speed-commands-section-levels)
    (setq latex-speed-commands--heading-regexp-cache
          (cons (copy-tree latex-speed-commands-section-levels)
                (concat "^\\([ \t]*\\)\\(%+[ \t]*\\)?\\\\\\("
                        (regexp-opt
                         (mapcar #'car latex-speed-commands-section-levels))
                        "\\)\\(\\*\\)?[ \t]*[[{]"))))
  (cdr latex-speed-commands--heading-regexp-cache))

(defun latex-speed-commands--level (name)
  "Return the outline level of the sectioning command NAME."
  (cdr (assoc name latex-speed-commands-section-levels)))

(defun latex-speed-commands--looking-at-heading ()
  "Return non-nil when the text after point is a heading line.
Point must be at the beginning of a line.  The match data is set."
  (and (bolp) (looking-at (latex-speed-commands--heading-regexp))))

(defun latex-speed-commands-at-heading-p ()
  "Return non-nil when point is at the beginning of a heading line.

A heading line is one that starts, after optional indentation and
an optional comment prefix, with a command in
`latex-speed-commands-section-levels'."
  (save-match-data (latex-speed-commands--looking-at-heading)))

(defun latex-speed-commands-at-environment-line-p ()
  "Return non-nil when point is at the beginning of a \\begin or \\end line."
  (and (bolp)
       (save-match-data
         (looking-at latex-speed-commands--environment-line-regexp))))

(defun latex-speed-commands--in-comment-p (pos &optional skip-prefix)
  "Return non-nil when POS follows an unescaped percent sign on its line.
When SKIP-PREFIX is non-nil, ignore the comment prefix at the start
of the line, so that a commented-out line reads as if it were not
commented."
  (save-excursion
    (goto-char pos)
    (let ((limit pos))
      (goto-char (line-beginning-position))
      (when skip-prefix
        (skip-chars-forward " \t")
        (skip-chars-forward "%"))
      (save-match-data
        (re-search-forward "\\(?:^\\|[^\\]\\)\\(?:\\\\\\\\\\)*%" limit t)))))

(defun latex-speed-commands--heading-start ()
  "Return the start of the heading line at or before point, or nil."
  (save-excursion
    (save-match-data
      (end-of-line)
      (when (re-search-backward (latex-speed-commands--heading-regexp) nil t)
        (match-beginning 0)))))

(defun latex-speed-commands--heading-level-at (pos)
  "Return the level of the heading at POS, or nil."
  (save-excursion
    (save-match-data
      (goto-char pos)
      (when (latex-speed-commands--looking-at-heading)
        (latex-speed-commands--level (match-string-no-properties 3))))))

(defun latex-speed-commands--section-end (beg level)
  "Return the end of the section of LEVEL with its heading at BEG.
The end is the start of the next heading of LEVEL or a higher rank,
the start of a line matching
`latex-speed-commands-section-boundary-regexp', or the end of the
buffer."
  (save-excursion
    (save-match-data
      (goto-char beg)
      (end-of-line)
      (let ((re (concat "\\(?:" (latex-speed-commands--heading-regexp) "\\)\\|"
                        "\\(?:" latex-speed-commands-section-boundary-regexp
                        "\\)"))
            (found nil))
        (while (and (not found) (re-search-forward re nil t))
          (if (match-beginning 3)
              (when (<= (latex-speed-commands--level
                         (match-string-no-properties 3))
                        level)
                (setq found (match-beginning 0)))
            (setq found (match-beginning 0))))
        (or found (point-max))))))

(defun latex-speed-commands--section-bounds ()
  "Return (BEG END LEVEL) for the section around point.
Signal a `user-error' when point is before the first heading."
  (let ((beg (latex-speed-commands--heading-start)))
    (unless beg
      (user-error "Before first heading"))
    (let ((level (latex-speed-commands--heading-level-at beg)))
      (list beg (latex-speed-commands--section-end beg level) level))))

(defun latex-speed-commands--headings-in (beg end)
  "Return the start positions of all headings between BEG and END."
  (save-excursion
    (save-match-data
      (goto-char beg)
      (let ((re (latex-speed-commands--heading-regexp)) result)
        (while (and (< (point) end) (re-search-forward re end t))
          (push (match-beginning 0) result)
          (end-of-line))
        (nreverse result)))))

(defun latex-speed-commands--previous-sibling (beg level)
  "Return the start of the sibling section before BEG at LEVEL, or nil.
A sibling must end exactly where the section at BEG starts."
  (save-excursion
    (save-match-data
      (goto-char beg)
      (let ((re (latex-speed-commands--heading-regexp)) result done)
        (while (and (not done) (not (bobp))
                    (progn (backward-char) (re-search-backward re nil t)))
          (let ((lv (latex-speed-commands--level
                     (match-string-no-properties 3)))
                (pos (match-beginning 0)))
            (cond ((< lv level) (setq done t))
                  ((= lv level)
                   (setq done t)
                   (when (= (latex-speed-commands--section-end pos level) beg)
                     (setq result pos))))))
        result))))

(defun latex-speed-commands--next-sibling (end level)
  "Return the start of the sibling section at END with LEVEL, or nil."
  (when (and (< end (point-max))
             (eql (latex-speed-commands--heading-level-at end) level))
    end))

(defun latex-speed-commands--read-braced (pos)
  "Read a brace group whose opening brace is just before POS.
Return a cons of the contents and the position after the closing
brace, or nil when the group is not closed."
  (save-excursion
    (save-match-data
      (goto-char pos)
      (let ((depth 1))
        (while (and (> depth 0) (re-search-forward "\\\\.\\|[{}]" nil t))
          (when (= (length (match-string 0)) 1)
            (setq depth (if (eq (char-before) ?{) (1+ depth) (1- depth)))))
        (when (= depth 0)
          (cons (buffer-substring-no-properties pos (1- (point)))
                (point)))))))

(defun latex-speed-commands--heading-title (pos)
  "Return (TITLE . END) for the heading at POS.
END is the position after the closing brace of the title."
  (save-excursion
    (save-match-data
      (goto-char pos)
      (when (latex-speed-commands--looking-at-heading)
        (goto-char (1- (match-end 0)))
        (when (eq (char-after) ?\[)
          (let ((depth 0) (done nil))
            (while (and (not done) (not (eobp)))
              (forward-char)
              (pcase (char-after)
                (?{ (setq depth (1+ depth)))
                (?} (setq depth (1- depth)))
                (?\] (when (= depth 0) (setq done t))))))
          (forward-char)
          (skip-chars-forward " \t\n"))
        (when (eq (char-after) ?{)
          (latex-speed-commands--read-braced (1+ (point))))))))

(defun latex-speed-commands--slugify (text)
  "Turn TEXT into a short string suitable for a label."
  (let* ((s (downcase (or text "")))
         (s (replace-regexp-in-string "\\\\[a-z@]+\\*?" " " s))
         (s (replace-regexp-in-string "[^a-z0-9]+" "-" s)))
    (string-trim s "-+" "-+")))

(defun latex-speed-commands--label-prefix (name)
  "Return the label prefix for heading or environment NAME."
  (let ((base (string-remove-suffix "*" name)))
    (or (cdr (assoc base latex-speed-commands-label-prefixes))
        (concat base ":"))))

(defun latex-speed-commands--toggle-comment-lines (beg end uncomment)
  "Comment or uncomment every line from BEG to END.
When UNCOMMENT is non-nil, remove one level of comment.  Otherwise
prefix every non-blank line with a percent sign and a space."
  (save-excursion
    (save-match-data
      (let ((end-marker (copy-marker end)))
        (goto-char beg)
        (while (< (point) end-marker)
          (cond (uncomment
                 (when (looking-at "[ \t]*\\(% ?\\)")
                   (delete-region (match-beginning 1) (match-end 1))))
                ((not (looking-at "[ \t]*$"))
                 (insert "% ")))
          (forward-line 1))
        (set-marker end-marker nil)))))


;;;; Activation and dispatch

(defun latex-speed-commands-heading-activate (keys)
  "Return the heading speed command for KEYS, or nil.
The command is active at the beginning of a heading line, or where
the function in `latex-speed-commands-use' returns non-nil.  This
is the analog of `org-speed-command-activate'.

For example, at the start of a \\section line, the call
\(latex-speed-commands-heading-activate \"k\") returns the symbol
`latex-speed-commands-kill-section'.  In body text it returns nil."
  (when (or (latex-speed-commands-at-heading-p)
            (and (functionp latex-speed-commands-use)
                 (funcall latex-speed-commands-use)))
    (cdr (assoc keys latex-speed-commands))))

(defun latex-speed-commands-environment-activate (keys)
  "Return the environment speed command for KEYS, or nil.
The command is active at the beginning of a \\begin or \\end line.
This is the analog of `org-babel-speed-command-activate'.

For example, at the start of a \\begin{equation} line, the call
\(latex-speed-commands-environment-activate \"e\") returns the symbol
`latex-speed-commands-goto-matching'."
  (when (latex-speed-commands-at-environment-line-p)
    (cdr (assoc keys latex-speed-commands-environment))))

(defun latex-speed-commands--lookup (key)
  "Return the speed command for the one-character string KEY, or nil."
  (and latex-speed-commands-mode
       latex-speed-commands-use
       (not (minibufferp))
       (run-hook-with-args-until-success
        'latex-speed-commands-activate-functions key)))

(defun latex-speed-commands--execute (cmd)
  "Execute the speed command CMD.
CMD is a command, a function, or a form, as in `org-speed-commands'."
  (cond ((commandp cmd)
         (setq this-command cmd)
         (call-interactively cmd))
        ((functionp cmd) (funcall cmd))
        ((consp cmd) (eval cmd t))
        (t (error "Invalid speed command: %S" cmd))))

(defun latex-speed-commands-dispatch ()
  "Run the speed command for the key that invoked this command.
The key map of `latex-speed-commands-mode' binds this command only
when a speed command is active, so other keys keep their normal
bindings."
  (interactive)
  (let ((cmd (and (characterp last-command-event)
                  (latex-speed-commands--lookup
                   (string last-command-event)))))
    (if cmd
        (latex-speed-commands--execute cmd)
      (call-interactively #'self-insert-command))))

(defun latex-speed-commands-move-safe (cmd)
  "Execute CMD, but make sure that point ends up at a heading.
If it does not, return to the original position and signal an
error.  This is the analog of `org-speed-move-safe'.

For example, the default entry for the key n is the form
\(latex-speed-commands-move-safe \\='latex-speed-commands-next-heading)."
  (interactive "CCommand: ")
  (let ((pos (point)))
    (condition-case err
        (call-interactively cmd)
      (error (goto-char pos)
             (signal (car err) (cdr err))))
    (unless (latex-speed-commands-at-heading-p)
      (goto-char pos)
      (user-error "Boundary reached while executing %s" cmd))))


;;;; Outline navigation

(defun latex-speed-commands-next-heading (&optional arg)
  "Move to the beginning of the next heading line.
With prefix ARG, move that many headings.

In the default `latex-speed-commands', the key is n.

Signal a `user-error' when there is no next heading, and leave
point where it was.

For example, with point at the start of \\section{Alpha}, the key
n moves point to the start of the next sectioning line."
  (interactive "p")
  (let ((pos (point)) (re (latex-speed-commands--heading-regexp)))
    (dotimes (_ (or arg 1))
      (end-of-line)
      (if (re-search-forward re nil t)
          (goto-char (match-beginning 0))
        (goto-char pos)
        (user-error "No next heading")))))

(defun latex-speed-commands-previous-heading (&optional arg)
  "Move to the beginning of the previous heading line.
With prefix ARG, move that many headings.

In the default `latex-speed-commands', the key is p.

Signal a `user-error' when there is no previous heading, and
leave point where it was."
  (interactive "p")
  (let ((pos (point)) (re (latex-speed-commands--heading-regexp)))
    (dotimes (_ (or arg 1))
      (beginning-of-line)
      (unless (and (not (bobp))
                   (progn (backward-char) (re-search-backward re nil t)))
        (goto-char pos)
        (user-error "No previous heading"))
      (goto-char (match-beginning 0)))))

(defun latex-speed-commands-forward-same-level (&optional arg)
  "Move to the next heading at the same level.
With prefix ARG, move that many siblings.

In the default `latex-speed-commands', the key is f.

Headings of a lower rank in between are skipped.  Signal a
`user-error' when the current section is the last one of its
parent.

For example, from \\section{Alpha} the key f skips
\\subsection{Alpha One} and lands on \\section{Beta}."
  (interactive "p")
  (let ((pos (point)))
    (dotimes (_ (or arg 1))
      (pcase-let* ((`(,_beg ,end ,level) (latex-speed-commands--section-bounds))
                   (next (latex-speed-commands--next-sibling end level)))
        (unless next
          (goto-char pos)
          (user-error "No following same-level heading"))
        (goto-char next)))))

(defun latex-speed-commands-backward-same-level (&optional arg)
  "Move to the previous heading at the same level.
With prefix ARG, move that many siblings.

In the default `latex-speed-commands', the key is b.

When point is inside the body of a section, move to the heading
of that section.  Signal a `user-error' when the current section
is the first one of its parent."
  (interactive "p")
  (let ((pos (point)))
    (dotimes (_ (or arg 1))
      (pcase-let* ((`(,beg ,_end ,level) (latex-speed-commands--section-bounds))
                   (prev (if (< (point) beg) nil
                           (if (> (point) beg) beg
                             (latex-speed-commands--previous-sibling
                              beg level)))))
        (unless prev
          (goto-char pos)
          (user-error "No previous same-level heading"))
        (goto-char prev)))))

(defun latex-speed-commands-up-heading ()
  "Move to the heading of the parent section.

In the default `latex-speed-commands', the key is u.

Signal a `user-error' when the current heading has the highest
rank in the outline, or when point is before the first heading.

For example, from \\subsection{Alpha One} the key u moves to
\\section{Alpha}."
  (interactive)
  (pcase-let ((`(,beg ,_end ,level) (latex-speed-commands--section-bounds))
              (re (latex-speed-commands--heading-regexp))
              (target nil))
    (save-excursion
      (goto-char beg)
      (while (and (not target) (not (bobp))
                  (progn (backward-char) (re-search-backward re nil t)))
        (when (< (latex-speed-commands--level (match-string-no-properties 3))
                 level)
          (setq target (match-beginning 0)))))
    (unless target
      (user-error "Already at top level of the outline"))
    (goto-char target)))

(defun latex-speed-commands-back-to-heading ()
  "Move to the heading of the section around point.

In the default `latex-speed-commands-environment', the key is h.

Signal a `user-error' when point is before the first heading."
  (interactive)
  (goto-char (car (latex-speed-commands--section-bounds))))


;;;; Outline visibility

(defun latex-speed-commands--ensure-outline ()
  "Turn on `outline-minor-mode' if it is not already on."
  (unless (bound-and-true-p outline-minor-mode)
    (outline-minor-mode 1)))

(defun latex-speed-commands-cycle ()
  "Cycle the visibility of the current section.
This turns on `outline-minor-mode' when needed and calls
`outline-cycle'.  It is the analog of `org-cycle'.

In the default `latex-speed-commands', the key is c.

Repeated presses fold the section, show its child headings, and
show everything, in the same order as in Org."
  (interactive)
  (latex-speed-commands--ensure-outline)
  (outline-cycle))

(defun latex-speed-commands-cycle-buffer ()
  "Cycle the visibility of the whole buffer.
This is the analog of `org-shifttab'.

In the default `latex-speed-commands', the key is C.

Repeated presses show only top headings, all headings, and the
whole buffer."
  (interactive)
  (latex-speed-commands--ensure-outline)
  (outline-cycle-buffer))

(defun latex-speed-commands--outline-path ()
  "Return the list of heading titles from the top level to point."
  (save-excursion
    (save-match-data
      (let ((start (latex-speed-commands--heading-start))
            (re (latex-speed-commands--heading-regexp))
            path level)
        (when start
          (goto-char start)
          (setq level (latex-speed-commands--heading-level-at start))
          (push (or (car (latex-speed-commands--heading-title start)) "") path)
          (while (and (not (bobp))
                      (progn (backward-char) (re-search-backward re nil t)))
            (let ((lv (latex-speed-commands--level
                       (match-string-no-properties 3)))
                  (pos (match-beginning 0)))
              (when (< lv level)
                (setq level lv)
                (push (or (car (latex-speed-commands--heading-title pos)) "")
                      path)))))
        path))))

(defun latex-speed-commands-display-outline-path ()
  "Display the path of headings that leads to the current section.
This is the analog of `org-display-outline-path'.

In the default `latex-speed-commands', the key is SPC.

For example, inside \\subsection{Alpha One} of
\\section{Alpha} of \\chapter{Introduction}, the echo area shows
Introduction / Alpha / Alpha One."
  (interactive)
  (let ((path (latex-speed-commands--outline-path)))
    (message "%s" (if path (mapconcat #'identity path " / ") "Top level"))))

(defun latex-speed-commands-toggle-narrow-to-section ()
  "Narrow to the current section, or widen when already narrowed.
This is the analog of `org-toggle-narrow-to-subtree'.

In the default `latex-speed-commands', the key is s.

Signal a `user-error' when point is before the first heading."
  (interactive)
  (if (buffer-narrowed-p)
      (widen)
    (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
      (narrow-to-region beg end)
      (goto-char beg))))

(defun latex-speed-commands-kill-section ()
  "Kill the current section, including all of its subsections.
The text goes to the kill ring.  This is the analog of
`org-cut-subtree'.

In the default `latex-speed-commands', the key is k.

Signal a `user-error' when point is before the first heading.  Yank the
section back with \\[yank]."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (kill-region beg end)
    (message "Section killed")))

(defun latex-speed-commands-copy-section ()
  "Copy the current section to the kill ring.
This is the analog of `org-copy-subtree'.

In the default `latex-speed-commands', the key is w.

Signal a `user-error' when point is before the first heading.  The buffer
is not changed."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (kill-ring-save beg end)
    (message "Section copied")))

(defun latex-speed-commands-count-words-section ()
  "Report the number of words in the current section.

In the default `latex-speed-commands', the key is =.

Return the number of words as an integer.  Signal a `user-error'
when point is before the first heading."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (let ((n (count-words beg end)))
      (message "Section has %d word%s" n (if (= n 1) "" "s"))
      n)))


;;;; Outline structure editing

(defun latex-speed-commands--section-text (beg end)
  "Return the text from BEG to END, ending with a newline."
  (let ((text (buffer-substring beg end)))
    (if (string-suffix-p "\n" text) text (concat text "\n"))))

(defun latex-speed-commands-move-section-up ()
  "Swap the current section with the previous sibling section.
This is the analog of `org-move-subtree-up'.

In the default `latex-speed-commands', the key is U.

Subsections travel with their section.  Signal a `user-error'
when there is no previous sibling.

For example, with \\section{Alpha} followed by \\section{Beta},
the key U on Beta puts Beta, with all of its text, before Alpha."
  (interactive)
  (pcase-let* ((`(,beg ,end ,level) (latex-speed-commands--section-bounds))
               (prev (latex-speed-commands--previous-sibling beg level)))
    (unless prev
      (user-error "Cannot move past superior level or buffer limit"))
    (let ((text (latex-speed-commands--section-text beg end)))
      (delete-region beg end)
      (goto-char prev)
      (insert text)
      (goto-char prev))))

(defun latex-speed-commands-move-section-down ()
  "Swap the current section with the next sibling section.
This is the analog of `org-move-subtree-down'.

In the default `latex-speed-commands', the key is D.

Subsections travel with their section.  Signal a `user-error'
when there is no next sibling."
  (interactive)
  (pcase-let* ((`(,beg ,end ,level) (latex-speed-commands--section-bounds))
               (next (latex-speed-commands--next-sibling end level)))
    (unless next
      (user-error "Cannot move past superior level or buffer limit"))
    (let* ((next-end (latex-speed-commands--section-end next level))
           (text (latex-speed-commands--section-text next next-end)))
      (delete-region next next-end)
      (goto-char beg)
      (insert text)
      (goto-char (+ beg (length text))))))

(defun latex-speed-commands--neighbor-name (name delta)
  "Return the sectioning command one rank below NAME when DELTA is 1.
Return the one above when DELTA is -1.  Return nil at the limits."
  (let* ((sorted (sort (copy-sequence latex-speed-commands-section-levels)
                       (lambda (a b) (< (cdr a) (cdr b)))))
         (names (mapcar #'car sorted))
         (idx (cl-position name names :test #'string=))
         (new (and idx (+ idx delta))))
    (and new (>= new 0) (< new (length names)) (nth new names))))

(defun latex-speed-commands--shift-headings (positions delta)
  "Shift the headings that start at POSITIONS by DELTA ranks.
Check every heading before changing any, so that the change is
all or nothing."
  (let ((plan
         (mapcar
          (lambda (pos)
            (save-excursion
              (goto-char pos)
              (latex-speed-commands--looking-at-heading)
              (let* ((name (match-string-no-properties 3))
                     (new (latex-speed-commands--neighbor-name name delta)))
                (unless new
                  (user-error "Cannot %s \\%s"
                              (if (> delta 0) "demote" "promote") name))
                (cons pos new))))
          positions)))
    (save-excursion
      (dolist (step (reverse plan))
        (goto-char (car step))
        (latex-speed-commands--looking-at-heading)
        (replace-match (cdr step) t t nil 3)))))

(defun latex-speed-commands-demote-heading ()
  "Demote the current heading line only, for example section to subsection.
This is the analog of `org-do-demote'.

In the default `latex-speed-commands', the key is r.

Signal a `user-error' when the heading already has the lowest
rank in `latex-speed-commands-section-levels'."
  (interactive)
  (latex-speed-commands--shift-headings
   (list (car (latex-speed-commands--section-bounds))) 1))

(defun latex-speed-commands-promote-heading ()
  "Promote the current heading line only, for example subsection to section.
This is the analog of `org-do-promote'.

In the default `latex-speed-commands', the key is l.

Signal a `user-error' when the heading already has the highest
rank in `latex-speed-commands-section-levels'."
  (interactive)
  (latex-speed-commands--shift-headings
   (list (car (latex-speed-commands--section-bounds))) -1))

(defun latex-speed-commands-demote-section ()
  "Demote the current heading and every heading inside its section.
This is the analog of `org-demote-subtree'.

In the default `latex-speed-commands', the key is R.

Nothing changes when any of the headings cannot be demoted, and
a `user-error' is signaled.

For example, \\section{Alpha} with \\subsection{Alpha One}
becomes \\subsection{Alpha} with \\subsubsection{Alpha One}."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (latex-speed-commands--shift-headings
     (latex-speed-commands--headings-in beg end) 1)))

(defun latex-speed-commands-promote-section ()
  "Promote the current heading and every heading inside its section.
This is the analog of `org-promote-subtree'.

In the default `latex-speed-commands', the key is L.

Nothing changes when any of the headings cannot be promoted, and
a `user-error' is signaled."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (latex-speed-commands--shift-headings
     (latex-speed-commands--headings-in beg end) -1)))

(defun latex-speed-commands-insert-heading-respect-content ()
  "Insert a new heading of the same level after the current section.
Point ends up between the braces of the new heading.  This is the
analog of `org-insert-heading-respect-content'.

In the default `latex-speed-commands', the key is i.

The new heading uses the same command as the current one, without
a star.  Signal a `user-error' when point is before the first heading."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (let ((name (save-excursion
                  (goto-char beg)
                  (latex-speed-commands--looking-at-heading)
                  (match-string-no-properties 3))))
      (goto-char end)
      (unless (bolp) (insert "\n"))
      (unless (or (bobp)
                  (save-excursion (forward-line -1) (looking-at "[ \t]*$")))
        (insert "\n"))
      (insert "\\" name "{}\n\n")
      (backward-char 3))))

(defun latex-speed-commands-mark-section ()
  "Put point at the start of the current section and mark at its end.
This is the analog of `org-mark-subtree'.

In the default `latex-speed-commands', the key is @.

The region is active afterward when Transient Mark mode is on.
Signal a `user-error' when point is before the first heading."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (goto-char beg)
    (push-mark end nil t)))

(defun latex-speed-commands-toggle-comment-section ()
  "Comment out the current section, or uncomment it when it is commented.
A commented section stays a heading for navigation, in the same way
that an Org COMMENT headline does.  This is the analog of
`org-toggle-comment'.

In the default `latex-speed-commands', the key is #.

Commenting adds a percent sign and a space to every non-blank
line.  Uncommenting removes one level, so comments that were
already in the section survive the round trip."
  (interactive)
  (pcase-let ((`(,beg ,end ,_) (latex-speed-commands--section-bounds)))
    (let ((commented (save-excursion
                       (goto-char beg)
                       (latex-speed-commands--looking-at-heading)
                       (match-beginning 2))))
      (latex-speed-commands--toggle-comment-lines beg end commented)
      (goto-char beg))))


;;;; Heading editing

(defun latex-speed-commands-toggle-heading-star ()
  "Toggle between a numbered and an unnumbered heading.
For example, \\section{...} becomes \\section*{...} and back.

In the default `latex-speed-commands', the key is *.

Signal a `user-error' when point is before the first heading."
  (interactive)
  (pcase-let ((`(,beg ,_ ,_) (latex-speed-commands--section-bounds)))
    (save-excursion
      (goto-char beg)
      (latex-speed-commands--looking-at-heading)
      (if (match-beginning 4)
          (delete-region (match-beginning 4) (match-end 4))
        (goto-char (match-end 3))
        (insert "*")))))

(defun latex-speed-commands--label-after (pos)
  "Return match bounds of a \\label that directly follows POS.
The label may be on the same line or on the next line.  Return a
cons of the start and end of the label text, or nil."
  (save-excursion
    (save-match-data
      (goto-char pos)
      (when (looking-at "[ \t]*\\(?:%.*\\)?\\(?:\n[ \t]*\\)?\\\\label{\\([^}\n]*\\)}")
        (cons (match-beginning 1) (match-end 1))))))

(defun latex-speed-commands--replace-or-insert-label
    (existing insert-pos default label)
  "Set a label.
EXISTING is a cons of the bounds of an existing label text, or nil.
INSERT-POS is where a new label line goes when there is none.
DEFAULT is the proposed label.  LABEL, when non-nil, is used
without prompting."
  (let* ((old (and existing
                   (buffer-substring-no-properties (car existing)
                                                   (cdr existing))))
         (new (or label (read-string "Label: " (or old default)))))
    (save-excursion
      (if existing
          (progn (goto-char (car existing))
                 (delete-region (car existing) (cdr existing))
                 (insert new))
        (goto-char insert-pos)
        (end-of-line)
        (insert "\n\\label{" new "}")
        (indent-according-to-mode)))
    new))

(defun latex-speed-commands-set-section-label (&optional label)
  "Add or edit the \\label of the current heading.
When there is no label, propose one built from the title and the
prefix in `latex-speed-commands-label-prefixes'.  When LABEL is
non-nil, use it without prompting.  This plays the role of
`org-set-tags-command'.  Return the label.

In the default `latex-speed-commands', the key is :.

For example, on \\section{Results and \\emph{Discussion}} with no
label, the proposed label is sec:results-and-discussion and it
goes on a new line after the heading."
  (interactive)
  (pcase-let ((`(,beg ,_ ,_) (latex-speed-commands--section-bounds)))
    (let* ((name (save-excursion
                   (goto-char beg)
                   (latex-speed-commands--looking-at-heading)
                   (match-string-no-properties 3)))
           (title (latex-speed-commands--heading-title beg))
           (after (if title (cdr title) (save-excursion
                                          (goto-char beg)
                                          (line-end-position))))
           (default (concat (latex-speed-commands--label-prefix name)
                            (latex-speed-commands--slugify (car title)))))
      (latex-speed-commands--replace-or-insert-label
       (latex-speed-commands--label-after after) after default label))))

(defun latex-speed-commands--heading-preamble-end ()
  "Return the end of the current heading line and any label after it."
  (pcase-let ((`(,beg ,_ ,_) (latex-speed-commands--section-bounds)))
    (let* ((title (latex-speed-commands--heading-title beg))
           (after (if title (cdr title)
                    (save-excursion (goto-char beg) (line-end-position))))
           (label (latex-speed-commands--label-after after)))
      (save-excursion
        (goto-char (if label (cdr label) after))
        (line-end-position)))))

(defun latex-speed-commands-insert-environment ()
  "Insert an environment after the heading line and its label.
Use `LaTeX-environment' in AUCTeX buffers and `latex-insert-block'
in buffers of the built-in `latex-mode'.

In the default `latex-speed-commands', the key is e.

When neither AUCTeX nor `latex-mode' is available, prompt for the
name and insert an empty environment.  Signal a `user-error' when
point is before the first heading."
  (interactive)
  (goto-char (latex-speed-commands--heading-preamble-end))
  (insert "\n")
  (cond ((and (bound-and-true-p TeX-mode-p) (fboundp 'LaTeX-environment))
         (call-interactively #'LaTeX-environment))
        ((fboundp 'latex-insert-block)
         (call-interactively #'latex-insert-block))
        (t
         (let ((name (read-string "Environment: ")))
           (insert "\\begin{" name "}\n\n\\end{" name "}")
           (forward-line -1)))))


;;;; Environments

(defun latex-speed-commands--scan-environment (forward commented)
  "Find the matching environment token starting from point.
Search forward for the matching \\end when FORWARD is non-nil, and
backward for the matching \\begin otherwise.  When COMMENTED is
nil, ignore tokens inside comments.  When COMMENTED is non-nil,
the environment is commented out, so read each line without its
comment prefix and ignore only the comments that remain.  Return
a list of the token start, the token end, the name start, and
the name end."
  (let ((depth 1) result)
    (while (and (not result)
                (if forward
                    (re-search-forward
                     latex-speed-commands--environment-token-regexp nil t)
                  (re-search-backward
                   latex-speed-commands--environment-token-regexp nil t)))
      (unless (latex-speed-commands--in-comment-p (match-beginning 0) commented)
        (let ((is-begin (string= (match-string-no-properties 1) "begin")))
          (setq depth (if (eq is-begin (and forward t)) (1+ depth) (1- depth)))
          (when (= depth 0)
            (setq result (list (match-beginning 0) (match-end 0)
                               (match-beginning 2) (match-end 2)))))))
    (or result (user-error "Unbalanced environment"))))

(defun latex-speed-commands--environment-info ()
  "Return a plist for the environment on this \\begin or \\end line.
The keys are :begin (start of the \\begin line), :end (after the
\\end line), :name, :begin-name and :end-name (conses with the
bounds of the name in each token), :begin-token-end, and
:commented."
  (save-excursion
    (save-match-data
      (beginning-of-line)
      (unless (looking-at latex-speed-commands--environment-line-regexp)
        (user-error "Not on a \\begin or \\end line"))
      (let* ((commented (and (match-beginning 2) t))
             (kind (match-string-no-properties 3))
             (name (match-string-no-properties 4))
             (here (list (- (match-beginning 3) 1) (match-end 0)
                         (match-beginning 4) (match-end 4)))
             begin-tok end-tok)
        (if (string= kind "begin")
            (progn (setq begin-tok here)
                   (goto-char (nth 1 here))
                   (setq end-tok (latex-speed-commands--scan-environment
                                  t commented)))
          (setq end-tok here)
          (goto-char (nth 0 here))
          (setq begin-tok (latex-speed-commands--scan-environment
                           nil commented)))
        (list :begin (save-excursion (goto-char (nth 0 begin-tok))
                                     (line-beginning-position))
              :end (save-excursion (goto-char (nth 1 end-tok))
                                   (end-of-line)
                                   (if (eobp) (point) (1+ (point))))
              :name name
              :begin-token-end (nth 1 begin-tok)
              :begin-name (cons (nth 2 begin-tok) (nth 3 begin-tok))
              :end-name (cons (nth 2 end-tok) (nth 3 end-tok))
              :commented commented)))))

(defun latex-speed-commands-next-environment (&optional arg)
  "Move to the beginning of the next line beginning with \\begin.
With prefix ARG, move that many environments.  This is the analog
of `org-next-block'.

In the default `latex-speed-commands', the key is F.
In the default `latex-speed-commands-environment', the key is n.

Signal a `user-error' when there is no next environment, and
leave point where it was."
  (interactive "p")
  (let ((pos (point))
        (re "^[ \t]*\\(?:%+[ \t]*\\)?\\\\begin[ \t]*{"))
    (dotimes (_ (or arg 1))
      (end-of-line)
      (if (re-search-forward re nil t)
          (goto-char (match-beginning 0))
        (goto-char pos)
        (user-error "No next environment")))))

(defun latex-speed-commands-previous-environment (&optional arg)
  "Move to the beginning of the previous line beginning with \\begin.
With prefix ARG, move that many environments.  This is the analog
of `org-previous-block'.

In the default `latex-speed-commands', the key is B.
In the default `latex-speed-commands-environment', the key is p.

Signal a `user-error' when there is no previous environment, and
leave point where it was."
  (interactive "p")
  (let ((pos (point))
        (re "^[ \t]*\\(?:%+[ \t]*\\)?\\\\begin[ \t]*{"))
    (dotimes (_ (or arg 1))
      (beginning-of-line)
      (unless (and (not (bobp))
                   (progn (backward-char) (re-search-backward re nil t)))
        (goto-char pos)
        (user-error "No previous environment"))
      (goto-char (match-beginning 0)))))

(defun latex-speed-commands-goto-matching ()
  "Jump between the \\begin and \\end lines of the current environment.

In the default `latex-speed-commands-environment', the key is e.

Nested environments and environments inside comments are skipped
while matching.  Signal a `user-error' when point is not on a
\\begin or \\end line, or when the environment is not closed."
  (interactive)
  (let ((info (latex-speed-commands--environment-info)))
    (if (save-excursion
          (beginning-of-line)
          (looking-at latex-speed-commands--environment-line-regexp)
          (string= (match-string-no-properties 3) "begin"))
        (progn (goto-char (car (plist-get info :end-name)))
               (beginning-of-line))
      (goto-char (plist-get info :begin)))))

(defun latex-speed-commands-up-environment ()
  "Move to the \\begin line of the environment that encloses this one.

In the default `latex-speed-commands-environment', the key is u.

Signal a `user-error' when no environment encloses the current
one."
  (interactive)
  (let* ((info (latex-speed-commands--environment-info))
         (target (save-excursion
                   (goto-char (car (plist-get info :begin-name)))
                   (search-backward "\\begin" nil t)
                   (condition-case nil
                       (nth 0 (latex-speed-commands--scan-environment
                               nil (plist-get info :commented)))
                     (user-error nil)))))
    (unless target
      (user-error "No enclosing environment"))
    (goto-char target)
    (beginning-of-line)))

(defun latex-speed-commands--environment-names ()
  "Return a list of environment names for completion."
  (delete-dups
   (append (and (bound-and-true-p TeX-mode-p)
                (fboundp 'LaTeX-environment-list)
                (mapcar (lambda (e) (if (consp e) (car e) e))
                        (LaTeX-environment-list)))
           (and (boundp 'latex-standard-block-names)
                (copy-sequence latex-standard-block-names))
           (list "itemize" "enumerate" "description" "equation" "equation*"
                 "align" "align*" "figure" "table" "tabular" "center"
                 "quote" "verbatim" "minted" "frame" "abstract"))))

(defun latex-speed-commands--rename-environment (info new)
  "Rename the environment described by INFO to NEW."
  (save-excursion
    (let ((e (plist-get info :end-name))
          (b (plist-get info :begin-name)))
      (goto-char (car e))
      (delete-region (car e) (cdr e))
      (insert new)
      (goto-char (car b))
      (delete-region (car b) (cdr b))
      (insert new))))

(defun latex-speed-commands-change-environment (&optional new-name)
  "Change the name of the current environment in \\begin and \\end.
When NEW-NAME is non-nil, use it without prompting.

In the default `latex-speed-commands-environment', the key is c.

Return the new name.  Completion offers the environments that
AUCTeX knows about, the standard LaTeX blocks, and a few common
ones.

For example, on \\begin{itemize} the call
\(latex-speed-commands-change-environment \"enumerate\") renames
both \\begin{itemize} and the matching \\end{itemize}."
  (interactive)
  (let* ((info (latex-speed-commands--environment-info))
         (new (or new-name
                  (completing-read
                   (format "Change environment %s to: " (plist-get info :name))
                   (latex-speed-commands--environment-names)
                   nil nil nil nil (plist-get info :name)))))
    (latex-speed-commands--rename-environment info new)
    new))

(defun latex-speed-commands-toggle-environment-star ()
  "Toggle the star of the current environment, as in equation and equation*.

In the default `latex-speed-commands-environment', the key is *.

Both the \\begin and the matching \\end change."
  (interactive)
  (let* ((info (latex-speed-commands--environment-info))
         (name (plist-get info :name)))
    (latex-speed-commands--rename-environment
     info (if (string-suffix-p "*" name)
              (substring name 0 -1)
            (concat name "*")))))

(defun latex-speed-commands-set-environment-label (&optional label)
  "Add or edit the \\label of the current environment.
An existing label inside the environment is edited.  Otherwise a
new label goes after the \\caption when there is one, and after the
\\begin line when there is none.  When LABEL is non-nil, use it
without prompting.  Return the label.

In the default `latex-speed-commands-environment', the key is :.

For example, in a figure with \\caption{Growth of \\textit{E.
coli}} the proposed label is fig:growth-of-e-coli."
  (interactive)
  (let* ((info (latex-speed-commands--environment-info))
         (limit (car (plist-get info :end-name)))
         (start (plist-get info :begin-token-end))
         existing caption-end caption)
    (save-excursion
      (save-match-data
        (goto-char start)
        (while (and (not existing) (re-search-forward "\\\\label{\\([^}\n]*\\)}"
                                                      limit t))
          (unless (latex-speed-commands--in-comment-p (match-beginning 0))
            (setq existing (cons (match-beginning 1) (match-end 1)))))
        (goto-char start)
        (when (re-search-forward "\\\\caption\\(?:\\[[^]]*\\]\\)?{" limit t)
          (let ((group (latex-speed-commands--read-braced (point))))
            (when group
              (setq caption (car group) caption-end (cdr group)))))))
    (latex-speed-commands--replace-or-insert-label
     existing (or caption-end start)
     (concat (latex-speed-commands--label-prefix (plist-get info :name))
             (latex-speed-commands--slugify caption))
     label)))

(defun latex-speed-commands-kill-environment ()
  "Kill the current environment, from the \\begin line to the \\end line.

In the default `latex-speed-commands-environment', the key is k.

Yank it back with \\[yank].  Signal a `user-error' when point is
not on a \\begin or \\end line."
  (interactive)
  (let ((info (latex-speed-commands--environment-info)))
    (kill-region (plist-get info :begin) (plist-get info :end))
    (message "Environment killed")))

(defun latex-speed-commands-copy-environment ()
  "Copy the current environment to the kill ring.

In the default `latex-speed-commands-environment', the key is w."
  (interactive)
  (let ((info (latex-speed-commands--environment-info)))
    (kill-ring-save (plist-get info :begin) (plist-get info :end))
    (message "Environment copied")))

(defun latex-speed-commands-mark-environment ()
  "Put point at the start of the current environment and mark at its end.

In the default `latex-speed-commands-environment', the key is @."
  (interactive)
  (let ((info (latex-speed-commands--environment-info)))
    (goto-char (plist-get info :begin))
    (push-mark (plist-get info :end) nil t)))

(defun latex-speed-commands-toggle-narrow-to-environment ()
  "Narrow to the current environment, or widen when already narrowed.

In the default `latex-speed-commands-environment', the key is s."
  (interactive)
  (if (buffer-narrowed-p)
      (widen)
    (let ((info (latex-speed-commands--environment-info)))
      (narrow-to-region (plist-get info :begin) (plist-get info :end))
      (goto-char (point-min)))))

(defun latex-speed-commands-toggle-comment-environment ()
  "Comment out the current environment, or uncomment it when commented.

In the default `latex-speed-commands-environment', the key is #.

A commented environment keeps its speed keys, so the same key
uncomments it."
  (interactive)
  (let ((info (latex-speed-commands--environment-info)))
    (latex-speed-commands--toggle-comment-lines
     (plist-get info :begin) (plist-get info :end)
     (plist-get info :commented))
    (goto-char (plist-get info :begin))))


;;;; Compile and view

(defun latex-speed-commands-compile ()
  "Compile the document.
Use `TeX-command-master' in AUCTeX buffers and `tex-file' in
buffers of the built-in `latex-mode'.

In the default `latex-speed-commands', the key is x.
The same key works on \\begin and \\end lines.

Signal a `user-error' when no compile command is available."
  (interactive)
  (cond ((and (bound-and-true-p TeX-mode-p) (fboundp 'TeX-command-master))
         (call-interactively #'TeX-command-master))
        ((fboundp 'tex-file) (call-interactively #'tex-file))
        (t (user-error "No LaTeX compile command is available"))))

(defun latex-speed-commands-view ()
  "View the compiled document.
Use `TeX-view' in AUCTeX buffers and `tex-view' in buffers of the
built-in `latex-mode'.

In the default `latex-speed-commands', the key is v.
The same key works on \\begin and \\end lines.

Signal a `user-error' when no view command is available."
  (interactive)
  (cond ((and (bound-and-true-p TeX-mode-p) (fboundp 'TeX-view))
         (call-interactively #'TeX-view))
        ((fboundp 'tex-view) (call-interactively #'tex-view))
        (t (user-error "No LaTeX view command is available"))))


;;;; Help

(defun latex-speed-commands--key-description (key)
  "Return a readable name for the one-character string KEY."
  (if (string= key " ") "SPC" key))

(defun latex-speed-commands--command-summary (cmd)
  "Return the first line of the documentation of CMD, or an empty string."
  (let* ((fn (cond ((symbolp cmd) cmd)
                   ((and (consp cmd)
                         (eq (car cmd) 'latex-speed-commands-move-safe))
                    (let ((arg (nth 1 cmd)))
                      (if (eq (car-safe arg) 'quote) (nth 1 arg) arg)))))
         (doc (and fn (fboundp fn) (ignore-errors (documentation fn t)))))
    (if doc (car (split-string doc "\n")) "")))

(defun latex-speed-commands--print-command (entry)
  "Print one ENTRY of a speed command alist to `standard-output'."
  (if (> (length (car entry)) 1)
      (progn (princ "\n")
             (princ (car entry))
             (princ "\n")
             (princ (make-string (length (car entry)) ?-))
             (princ "\n"))
    (princ (format "%-4s %-52s %s\n"
                   (latex-speed-commands--key-description (car entry))
                   (latex-speed-commands--command-name (cdr entry))
                   (latex-speed-commands--command-summary (cdr entry))))))

(defun latex-speed-commands--command-name (cmd)
  "Return a short printed name for the speed command CMD."
  (cond ((symbolp cmd) (symbol-name cmd))
        ((and (consp cmd) (eq (car cmd) 'latex-speed-commands-move-safe))
         (let ((arg (nth 1 cmd)))
           (format "%s (safe)"
                   (if (eq (car-safe arg) 'quote) (nth 1 arg) arg))))
        (t (prin1-to-string cmd))))

(defun latex-speed-commands-help ()
  "Show the available speed commands.
This is the analog of `org-speed-command-help'.

The key is ? at every speed position.  Signal a `user-error' when
`latex-speed-commands-use' is nil."
  (interactive)
  (unless latex-speed-commands-use
    (user-error "Speed commands are not activated, customize `latex-speed-commands-use'"))
  (with-output-to-temp-buffer "*Help*"
    (princ "LaTeX speed commands\n====================\n\n")
    (princ "At the beginning of a heading line such as \\section{...}\n")
    (princ "(`latex-speed-commands')\n")
    (mapc #'latex-speed-commands--print-command latex-speed-commands)
    (princ "\n\nAt the beginning of a \\begin{...} or \\end{...} line\n")
    (princ "(`latex-speed-commands-environment')\n")
    (mapc #'latex-speed-commands--print-command
          latex-speed-commands-environment)
    (princ "\n\nEvery other key inserts itself.  Use C-q KEY to insert a\n")
    (princ "speed key literally at one of these positions.\n"))
  (with-current-buffer "*Help*"
    (setq truncate-lines t)))


;;;; Minor mode

(defvar latex-speed-commands-mode-map
  (let ((map (make-sparse-keymap)))
    (dotimes (i 95)
      (let ((key (string (+ 32 i))))
        (define-key map (vector (+ 32 i))
                    `(menu-item
                      "" latex-speed-commands-dispatch
                      :filter ,(lambda (cmd)
                                 (and (latex-speed-commands--lookup key)
                                      cmd))))))
    map)
  "Keymap for `latex-speed-commands-mode'.
Every printable ASCII key has a conditional binding.  The binding
is active only when a speed command exists for the key at point.
Otherwise key lookup continues to the major mode and global maps,
so normal typing and AUCTeX electric keys are not affected.")

;;;###autoload
(define-minor-mode latex-speed-commands-mode
  "Toggle Org-style single-key speed commands in LaTeX buffers.

When this mode is on and point is at the beginning of a heading
line such as \\section{...}, the plain keys in
`latex-speed-commands' run outline commands instead of inserting
themselves.  At the beginning of a \\begin{...} or \\end{...} line,
the keys in `latex-speed-commands-environment' are active.  Press
the question mark key at one of these positions for a list of the
commands.

See `latex-speed-commands-use' for ways to activate the heading
commands at other positions."
  :lighter latex-speed-commands-lighter
  :keymap latex-speed-commands-mode-map
  :group 'latex-speed-commands)

(provide 'latex-speed-commands)
;;; latex-speed-commands.el ends here
