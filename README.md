![Version](https://img.shields.io/static/v1?label=latex-speed-commands&message=0.1.0&color=brightcolor)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Emacs](https://img.shields.io/badge/Emacs-28.1+-purple.svg)](https://www.gnu.org/software/emacs/)
[![CI](https://github.com/MooersLab/latex-speed-commands-el/actions/workflows/test.yml/badge.svg)](https://github.com/MooersLab/latex-speed-commands-el/actions/workflows/test.yml)

# latex-speed-commands

## Description

latex-speed-commands brings the single-key speed commands of Org mode
to LaTeX buffers in Emacs.  With point at the very beginning of a
sectioning line such as `\section{Results}`, plain keys like `n`, `p`,
`c` and `k` move between headings, fold sections, and cut subtrees,
exactly as they do at an Org headline.  At the beginning of a
`\begin{...}` or `\end{...}` line, a second set of keys works on the
environment, in the same way that the Babel keys work on an Org source
block.  The package is for people who write in Org and in LaTeX on the
same day and want one set of muscle memory for both.

Neither the built-in `latex-mode` nor AUCTeX offers anything like
this.  AUCTeX uses `C-c` prefixed commands and outline folding, but it
has no single-key commands at the beginning of a line.

## Features

- Uses the same keys as `org-speed-commands` wherever the job exists in
  LaTeX, so `n`, `p`, `f`, `b`, `u`, `c`, `C`, `SPC`, `s`, `k`, `U`,
  `D`, `r`, `l`, `R`, `L`, `i`, `@`, `#`, `:`, `j`, `/` and `?` carry
  over.
- Adds environment speed keys on `\begin` and `\end` lines to jump to
  the match, rename, star, label, kill, mark, narrow, and comment.
- Never shadows a key that has no speed command at point, so the
  electric `$`, `"` and `^` keys of AUCTeX keep working.
- Promotes and demotes `\section` to `\subsection` and back, one line or
  a whole section, with all-or-nothing safety at the limits.
- Proposes labels such as `sec:results-and-discussion` and
  `fig:growth-of-e-coli` from titles and captions.
- Treats `% \section{...}` as a commented heading, which is the analog
  of an Org `COMMENT` headline.
- Accepts a predicate in `latex-speed-commands-use`, like
  `org-use-speed-commands`, to activate the keys in the leftmost column
  of every line.
- Uses the same alist format and activation hook as Org, so your own
  commands slot in with one `push`.

## Prerequisites

- GNU Emacs 28.1 or newer.
- Optional: AUCTeX (tested with AUCTeX 14).  Without it, the package
  works with the built-in `latex-mode`.
- For development only: `git`, `make`, `makeinfo` (Texinfo), and
  optionally `pandoc` and `lcov`.

## Installation

### Install from MELPA

After the package is accepted on MELPA, you can install it with
`use-package`.

```elisp
(use-package latex-speed-commands
  :ensure t
  :hook ((LaTeX-mode . latex-speed-commands-mode)
         (latex-mode . latex-speed-commands-mode)))
```

### Install from source

Clone the repository.

```bash
git clone https://github.com/MooersLab/latex-speed-commands-el.git
```

Then add the following to your init file.

```elisp
(add-to-list 'load-path "/path/to/latex-speed-commands-el")
(require 'latex-speed-commands)
(add-hook 'LaTeX-mode-hook #'latex-speed-commands-mode) ; AUCTeX
(add-hook 'latex-mode-hook #'latex-speed-commands-mode) ; built-in
```

With `straight.el` or Elpaca, use the GitHub recipe below.

```elisp
(use-package latex-speed-commands
  :straight (:host github :repo "MooersLab/latex-speed-commands-el")
  :hook (LaTeX-mode . latex-speed-commands-mode))
```

### MELPA recipe

The recipe for the MELPA pull request is in [`recipes/latex-speed-commands`](recipes/latex-speed-commands).

```elisp
(latex-speed-commands :fetcher github
                      :repo "MooersLab/latex-speed-commands-el")
```

The default `:files` of MELPA pick up `latex-speed-commands.el` and
`docs/latex-speed-commands.texi`, so MELPA builds the Info manual.

## Usage

Turn on the minor mode in a LaTeX buffer.

```elisp
(require 'latex-speed-commands)
(latex-speed-commands-mode 1)
```

Or type the command interactively.

```text
M-x latex-speed-commands-mode
```

Move point to the very beginning of a `\section{...}` line and press
`?` for the list of speed commands.  Press `n` and `p` to move, `c` to
fold, `U` and `D` to reorder sections, and `F` to jump to the next
environment.  On a `\begin` line, press `e` to jump to the matching
`\end`.

To insert a speed key literally at a speed position, type `C-q` first,
as in `C-q n`.  This is the same trick that works in Org.

### Heading speed keys

| Key | Action | Org command with the same key |
|:----|:-------|:------------------------------|
| `n` | Next heading | `org-next-visible-heading` |
| `p` | Previous heading | `org-previous-visible-heading` |
| `f` | Next heading at the same level | `org-forward-heading-same-level` |
| `b` | Previous heading at the same level | `org-backward-heading-same-level` |
| `F` | Next `\begin` line | `org-next-block` |
| `B` | Previous `\begin` line | `org-previous-block` |
| `u` | Parent heading | `outline-up-heading` |
| `j` | Jump with `imenu` | `org-goto` |
| `c` | Cycle the visibility of the section | `org-cycle` |
| `C` | Cycle the visibility of the buffer | `org-shifttab` |
| `SPC` | Show the outline path | `org-display-outline-path` |
| `s` | Narrow to the section, or widen | `org-toggle-narrow-to-subtree` |
| `k` | Kill the section | `org-cut-subtree` |
| `w` | Copy the section | none (Org refiles) |
| `=` | Count the words in the section | none (Org shows columns) |
| `U` | Swap with the previous sibling | `org-metaup` |
| `D` | Swap with the next sibling | `org-metadown` |
| `r` | Demote the heading line | `org-metaright` |
| `l` | Promote the heading line | `org-metaleft` |
| `R` | Demote the whole section | `org-shiftmetaright` |
| `L` | Promote the whole section | `org-shiftmetaleft` |
| `i` | New heading after the section | `org-insert-heading-respect-content` |
| `@` | Mark the section | `org-mark-subtree` |
| `#` | Comment or uncomment the section | `org-toggle-comment` |
| `*` | Toggle `\section` and `\section*` | none |
| `:` | Add or edit the `\label` | `org-set-tags-command` |
| `e` | Insert an environment after the heading | none (Org sets effort) |
| `x` | Compile the document | none |
| `v` | View the output | none (Org opens the agenda) |
| `/` | Run `occur` | `org-sparse-tree` |
| `?` | Show the speed command help | `org-speed-command-help` |

### Environment speed keys

| Key | Action | Org or Babel analog |
|:----|:-------|:--------------------|
| `n` | Next `\begin` line | `org-babel-next-src-block` |
| `p` | Previous `\begin` line | `org-babel-previous-src-block` |
| `e` | Jump between `\begin` and `\end` | none |
| `u` | Enclosing environment | `org-babel-goto-src-block-head` |
| `h` | Back to the section heading | none |
| `c` | Change the environment name | none |
| `*` | Toggle the star, as in `equation*` | none |
| `:` | Add or edit the `\label` | `org-set-tags-command` |
| `s` | Narrow to the environment, or widen | `org-toggle-narrow-to-subtree` |
| `k` | Kill the environment | `org-cut-subtree` |
| `w` | Copy the environment | none |
| `@` | Mark the environment | `org-mark-subtree` |
| `#` | Comment or uncomment the environment | `org-toggle-comment` |
| `x`, `v`, `/`, `?` | Compile, view, occur, help | as above |

Org keys with no LaTeX analog (`g`, `^`, `a`, `I`, `O`, `t`, `,`, `0`
to `3`, `E`, `W`, `o`, `<`, `>`) insert themselves.  You can give them
your own commands.

## Configuration

Type `M-x customize-group RET latex-speed-commands RET` to see every
option.

| Option | Description | Default |
|:-------|:------------|:--------|
| `latex-speed-commands-use` | `nil` turns the keys off, `t` uses headings and environment lines, a function adds the positions where it returns non-nil | `t` |
| `latex-speed-commands` | Alist of keys and commands at heading lines, in the format of `org-speed-commands` | see above |
| `latex-speed-commands-environment` | Alist of keys and commands at `\begin` and `\end` lines | see above |
| `latex-speed-commands-activate-functions` | Hook that picks the command for a key, like `org-speed-command-hook` | environment, then heading |
| `latex-speed-commands-section-levels` | Sectioning commands and their outline levels | `\part` 0 to `\subparagraph` 6 |
| `latex-speed-commands-section-boundary-regexp` | Lines that end every section before them | `\end{document}`, `\appendix`, bibliography |
| `latex-speed-commands-label-prefixes` | Label prefixes such as `sec:` and `fig:` | common LaTeX prefixes |
| `latex-speed-commands-lighter` | Mode line text | `" Speed"` |

Speed keys in the leftmost column of every line work like this.

```elisp
(setq latex-speed-commands-use #'bolp)
```

Add your own keys by pushing entries onto the front of an alist.

```elisp
(with-eval-after-load 'latex-speed-commands
  (push '("t" . (progn (end-of-line) (insert "\n\\todo{}") (backward-char)))
        latex-speed-commands)
  (push '("g" . consult-outline) latex-speed-commands))
```

Beamer users can add `\frametitle` as the lowest heading level.

```elisp
(add-to-list 'latex-speed-commands-section-levels '("frametitle" . 7) t)
```

## Testing

### Prerequisites

The tests use ERT, which ships with Emacs.  Coverage uses undercover.el,
and the linter uses package-lint.  The integration tests also run
against AUCTeX when a copy is available.  Install all of these into the
local `.deps/` directory with one command.

```bash
make install-test-deps
```

### Quick start

```bash
make test
```

### Available make targets

| Target | Description |
|:-------|:------------|
| `make test` | Run all tests (unit + integration) via ERT |
| `make test-unit` | Run unit tests only (tests without the integration tag) |
| `make test-integration` | Run integration tests only (command loop and AUCTeX) |
| `make coverage` | Run tests with undercover.el and print line coverage |
| `make coverage-html` | Generate an HTML coverage report in `htmlcov/` |
| `make coverage-check` | Fail if line coverage is below 90% |
| `make lint` | Byte-compile, checkdoc, and package-lint |
| `make lint-checkdoc` | Run checkdoc and fail on any warning |
| `make lint-package` | Run package-lint (MELPA requirements) |
| `make compile` | Byte-compile the package and fail on any warning |
| `make install-test-deps` | Clone AUCTeX, package-lint, undercover, dash, and shut-up into `.deps` |
| `make clean` | Remove byte code, coverage reports, and generated docs |
| `make help` | Show this help message |

### Run specific tests

Run one test, or every test whose name matches a regexp, with
`test-one`.

```bash
make test-one TEST=lsc-test-move-section-up-down
make test-one TEST='lsc-test-.*environment'
```

From inside Emacs, load `test/latex-speed-commands-test.el` and type
`M-x ert RET lsc-test-move-section-up-down RET`.  Use a different
AUCTeX checkout with `make test AUCTEX_DIR=/path/to/auctex`.

### Coverage

```bash
make coverage        # prints the percentage
make coverage-html   # writes htmlcov/index.html (needs lcov)
make coverage-check  # fails below 90%
```

### Write new tests

Unit tests go in `test/latex-speed-commands-test.el`, and tests that
drive the real command loop or AUCTeX go in
`test/latex-speed-commands-integration-test.el`.  Name each test after
the behavior it checks, with the prefix `lsc-test-` for unit tests and
`lsc-integration-test-` for integration tests.  Shared fixtures such as
`lsc-test-document` and the `lsc-test-with-buffer` macro live in
`test/latex-speed-commands-test-helper.el`.  Wrap each test in
`lsc-test-with-buffer`, which builds a fresh `latex-mode` buffer, so no
state leaks between tests.  Use `lsc-test-goto` to move to a line and
`lsc-test-press` to simulate a key.  Stub prompts with `cl-letf` on
`read-string` or `completing-read`.  Mark an integration test with
`:tags '(integration)` so that `make test-unit` skips it.  Guard tests
that need AUCTeX with `skip-unless`, as the AUCTeX macro already does.

### Continuous integration

Every target exits with a nonzero status on failure, so any CI system
can call them directly.  The repository ships a GitHub Actions workflow
in `.github/workflows/test.yml` that tests Emacs 28.2, 29.4, 30.1, and
the development snapshot.  The core of the workflow looks like this.

```yaml
- uses: purcell/setup-emacs@master
  with:
    version: ${{ matrix.emacs_version }}
- run: make install-test-deps
- run: make lint test coverage-check docs-check
```

## Documentation

### Prerequisites

The manual is written in Org and exported to Texinfo with `ox-texinfo`,
which ships with Emacs.  `makeinfo` from Texinfo builds the Info and
HTML manuals, and `pandoc` (optional) builds the HTML landing page and
API page.  Check for the tools with one command.

```bash
make docs-deps
```

On macOS, install Texinfo with `brew install texinfo`.  On Debian or
Ubuntu, use `sudo apt install texinfo pandoc`.

### Quick start

```bash
make docs-open
```

### Available make targets

| Target | Description |
|:-------|:------------|
| `make docs` | Build the Info manual, the HTML manual, and the API reference |
| `make docs-serve` | Serve `docs/site` at http://localhost:8000 |
| `make docs-open` | Build the docs and open them in a browser |
| `make docs-api` | Regenerate the API reference from the docstrings |
| `make docs-check` | Fail if fewer than 90% of the symbols have docstrings |
| `make docs-lint` | Run checkdoc and a strict makeinfo pass on the manual |
| `make docs-deps` | Check for the documentation tools |
| `make docs-clean` | Remove generated documentation |
| `make texi` | Export the Org manual to Texinfo |
| `make info` | Build the Info manual |
| `make html` | Build the HTML manual in `docs/site/` |

### Where to find the docs

- `docs/latex-speed-commands.info` is the Info manual.  Read it in
  Emacs with `C-u C-h i docs/latex-speed-commands.info`.  After a MELPA
  install, it appears in the Info directory as `LaTeX Speed Commands`.
- `docs/site/index.html` is the landing page.  It links to
  `manual.html`, `api.html`, and `getting-started.html`.
- `docs/api/latex-speed-commands-api.md` is the API reference in
  Markdown, which GitHub renders directly.
- Inside Emacs, `C-h f` and `C-h v` show the same docstrings, and `?`
  at a speed position shows the key table.

### Live preview

```bash
make docs-serve
```

Then open http://localhost:8000.  The server does not reload by
itself, so run `make docs` in a second terminal after an edit and
refresh the browser.

### Write documentation

Docstrings go in `latex-speed-commands.el`, in the built-in docstring
of each `defun`, `defcustom`, and `defvar`.  Start each docstring with
a one-line summary in the imperative mood, then describe the arguments
in capital letters, the return value, and the errors.  Refer to other
symbols with backquote and apostrophe, as in
`` `latex-speed-commands-use' ``, which turns into a link in the Help
buffer.  Give an example in prose, and escape an open parenthesis at
the start of a line as `\(`.  Run `make lint-checkdoc` after an edit.
The user manual lives in `docs/latex-speed-commands.org`.  Add a new
chapter with a top-level heading, and add `#+cindex:` lines under it
for the index.  Use `#+findex:` and `#+vindex:` for functions and
options.  Add a new guide page as a Markdown file in `docs/guides/`
and link it from `docs/index.md`.  Put images in `docs/images/` and
include them with an Org link such as `[[file:images/fold.png]]`.  Run
`make texi` to refresh `docs/latex-speed-commands.texi`, and commit that
file, because MELPA builds the Info manual from it.

### Documentation coverage

```bash
make docs-check
```

The check loads the package and counts every function and variable
that `latex-speed-commands.el` defines.  It fails when fewer than 90%
of them have a docstring.  Change the threshold with
`make docs-check DOCS_MIN=100`.

### Hosting

The `docs/site/` directory is a static site, so any static host can
serve it.  For GitHub Pages, push the directory to a `gh-pages` branch
with `git subtree push --prefix docs/site origin gh-pages`, or publish
it from a workflow with `actions/upload-pages-artifact`.  Netlify and
Read the Docs can serve the same directory as a plain HTML site.  The
Info manual needs no hosting, because MELPA installs it with the
package.

## Contributing

Contributions are welcome!  Please read [CONTRIBUTING.md](CONTRIBUTING.md)
for guidelines on how to submit issues, feature requests, and pull
requests.  This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).  To cite
the package in academic work, see [CITATION.md](CITATION.md).

## License

This project is licensed under the GNU General Public License v3.0.
See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- The Org mode developers, for `org-speed-commands`, which this package
  imitates key for key.
- The AUCTeX developers, for the LaTeX editing environment that this
  package extends.
- Steve Purcell, for package-lint and setup-emacs.
- The undercover.el developers, for Emacs Lisp coverage reports.

## Update table

| Version | Changes                                                      | Date              |
|:---------|:--------------------------------------------------------------|:-------------------|
| 0.1.0   | Initiate project. Added badges, funding, and this update table. | 2026 November 07   |

## Sources of funding

- NIH: R01 CA242845
- NIH: R01 AI088011
- NIH: P30 CA225520 (PI: R. Mannel)
- NIH: P20 GM103640 and P30 GM145423 (PI: A. West)
