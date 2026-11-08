# latex-speed-commands documentation

latex-speed-commands brings the single-key speed commands of Org mode
to LaTeX buffers in Emacs.  At the beginning of a sectioning line such
as `\section{...}`, or of a `\begin{...}` or `\end{...}` line, plain
keys like `n`, `p`, `c` and `k` run outline commands.  Everywhere else
the keys type as usual.

## Where to start

- [Getting started](getting-started.html) walks through the first five
  minutes.  The source is `docs/guides/getting-started.md`.
- [The manual](manual.html) covers every key, option, and extension
  point.  The same manual is available in Emacs as Info.  Run
  `make info` and then type `C-u C-h i docs/latex-speed-commands.info`.
- [The API reference](api.html) is generated from the docstrings.  The
  Markdown source is `docs/api/latex-speed-commands-api.md`.

## Build these pages

```bash
make docs        # Info manual, HTML manual, and API reference
make docs-serve  # serve docs/site at http://localhost:8000
```
