# Contributing to latex-speed-commands

Thank you for considering a contribution to **latex-speed-commands**!
The following guidelines help keep the process smooth for everyone.

## Reporting bugs

If you find a bug, please open an issue using the
[bug report template](https://github.com/MooersLab/latex-speed-commands-el/issues/new?template=bug_report.md).

Include:

- A clear, descriptive title.
- Steps to reproduce the problem, ideally with a few lines of LaTeX.
- Expected and actual behavior.
- Your environment (OS, Emacs version, AUCTeX version or `latex-mode`,
  package version).

## Suggesting features

Feature ideas are welcome.  Please open an issue using the
[feature request template](https://github.com/MooersLab/latex-speed-commands-el/issues/new?template=feature_request.md).

Describe the problem you want to solve, your proposed solution, and any
alternatives you considered.  When you propose a new key, please say
which Org speed key it mirrors, because matching Org is the main design
goal.

## Development setup

1. Fork and clone the repository.

   ```bash
   git clone https://github.com/<your-fork>/latex-speed-commands-el.git
   cd latex-speed-commands-el
   ```

2. Install the development dependencies into `.deps/`.

   ```bash
   make install-test-deps
   ```

3. Run the tests, the linters, and the documentation checks.

   ```bash
   make test
   make lint
   make docs-check
   ```

## Pull request process

1. Create a feature branch from `main`.

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes in small, focused commits.

3. Write or update tests to cover your changes.  Keep `make
   coverage-check` above 90%.

4. Run the full test suite and confirm it passes.

5. If you changed the manual, run `make texi` and commit the updated
   `docs/latex-speed-commands.texi`.

6. Push your branch and open a pull request against `main`.

7. Fill in the pull request template completely.

8. Wait for a maintainer review.  Address any feedback promptly.

## Commit message conventions

Use the following format.

```text
<type>: <short summary>

<optional body explaining the "why">
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.

## Code style

- Follow the existing code style in the repository.
- Prefix every symbol with `latex-speed-commands-`, and use a double
  hyphen for internal symbols.
- Give every function and variable a docstring that passes checkdoc.
- Run the linter before submitting.

  ```bash
  make lint
  ```

## Code of conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to uphold this code.  Please report
unacceptable behavior to blaine-mooers@ou.edu.
