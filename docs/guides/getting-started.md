# Getting started with latex-speed-commands

This guide takes about five minutes.  You need Emacs 28.1 or newer.
AUCTeX is optional.

## Turn the mode on

Add one hook per LaTeX mode that you use.

```elisp
(require 'latex-speed-commands)
(add-hook 'LaTeX-mode-hook #'latex-speed-commands-mode) ; AUCTeX
(add-hook 'latex-mode-hook #'latex-speed-commands-mode) ; built-in
```

Open a `.tex` file.  The mode line shows `Speed`.

## Try the keys

Copy this small document into a buffer.

```latex
\documentclass{article}
\begin{document}
\section{Introduction}
Some text.
\subsection{Background}
More text.
\section{Methods}
\begin{equation}
  E = mc^2
\end{equation}
\end{document}
```

1. Put point at the very beginning of `\section{Introduction}`.
2. Press `?`.  The help buffer lists every speed command.
3. Press `n` twice.  Point moves to `\subsection{Background}` and then
   to `\section{Methods}`.
4. Press `p` and then `u`.  Point moves back to the subsection and then
   up to its parent section.
5. Press `c`.  The section folds.  Press `c` again to show its
   children, and once more to show everything.
6. Press `r`.  The heading becomes `\subsection{Introduction}`.  Press
   `l` to undo the demotion.
7. Press `n` until point is on `\section{Methods}`, then press `F`.
   Point lands on `\begin{equation}`.
8. Press `*`.  Both lines become `equation*`.  Press `e` to jump to the
   `\end` line and `e` again to jump back.
9. Press `:` and then `RET`.  A label such as `\label{eq:}` appears.

## Type normally

Move point one character to the right and press `n`.  The letter is
inserted, because point is no longer at a speed position.  To insert a
speed key at a speed position, type `C-q` first, as in `C-q n`.

## Next steps

- Read the manual with `C-u C-h i docs/latex-speed-commands.info`
  after `make info`, or open `docs/site/manual.html` after `make docs`.
- Set `latex-speed-commands-use` to `bolp` to get the heading keys at
  the start of every line.
- Push your own entries onto `latex-speed-commands` to fill the Org
  keys that LaTeX does not use, such as `t` or `g`.
