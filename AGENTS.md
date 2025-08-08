# Repository Guidelines

## Project Structure & Module Organization
- lib/github/pulse: Core library code (CLI, analyzers, clients, reporters). Example: `lib/github/pulse/cli.rb`.
- exe/: Executable entrypoint (`exe/github-pulse`).
- bin/: Dev helpers (`bin/setup`, `bin/console`).
- pkg/: Built gem artifacts (created by build tasks).
- Rakefile, Gemfile, *.gemspec: Build and dependency configuration.

## Build, Test, and Development Commands
- Install deps: `bin/setup` (runs `bundle install`).
- Run CLI locally: `exe/github-pulse analyze [REPO_PATH] [--repo owner/name] [--format json|pretty|html] [--since YYYY-MM-DD] [--until YYYY-MM-DD]`.
- Build gem: `rake build` (outputs to `pkg/`).
- Install gem locally: `bundle exec rake install`.
- Release (maintainers): `rake release`.
- Console: `bin/console` to experiment with `Github::Pulse` APIs.

## Coding Style & Naming Conventions
- Ruby 3.1+, 2-space indentation, frozen string literals (`# frozen_string_literal: true`).
- Namespace modules under `Github::Pulse`; place files at `lib/github/pulse/<name>.rb`.
- Method and file names: snake_case; classes/modules: CamelCase.
- No linter is enforced; follow existing style and keep methods small and composable.

## Testing Guidelines
- This repository currently has no test suite. If adding tests, prefer RSpec:
  - Directory: `spec/` mirroring `lib/` paths (e.g., `spec/github/pulse/analyzer_spec.rb`).
  - Naming: `*_spec.rb`. Run with `bundle exec rspec`.
- For manual verification, run:
  - Local git: `exe/github-pulse analyze . --format=pretty`.
  - With GitHub data: set `GITHUB_TOKEN` or authenticate `gh`, then `--format=html` and open the generated report.

## Commit & Pull Request Guidelines
- Commits: concise imperative subject (<= 72 chars), body with rationale and user-visible impact. Group related changes.
- Branches: use descriptive names like `feature/report-html`, `fix/commit-stats`.
- Pull Requests must include:
  - Clear description, checklist of changes, and rationale.
  - Linked issue (if applicable).
  - Usage proof: sample command and excerpt of output (JSON/HTML path).
  - Notes on backward compatibility and dependency changes.

## Security & Configuration Tips
- GitHub access: provide `--token`, set `GITHUB_TOKEN`, or authenticate `gh`.
- Do not commit tokens or secrets. Prefer environment variables and `.gitignore`d files.
- Local analysis requires a valid `.git` repo; GitHub data requires network access and auth.

