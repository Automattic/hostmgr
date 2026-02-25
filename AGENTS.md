# hostmgr

A suite of tools for managing macOS virtual machines using Apple's Virtualization framework.
Designed for Automattic's our Mac CI infrastructure, which uses S3 to store VM templates, and Buildkite for CI orchestration.

Only supports Apple Silicon / ARM64.

## Project Structure

```
Sources/
  hostmgr/             # CLI tool
  hostmgr-helper/      # macOS menu bar app
  libhostmgr/          # Shared library (VM lifecycle, config, networking)
  tinys3/              # Minimal S3 client
  tinys3-cli/          # CLI wrapper for tinys3
Tests/
  hostmgrTests/
  hostmgr-helperTests/
  libhostmgrTests/
  tinys3Tests/
fastlane/              # Code signing and release automation
.buildkite/            # CI pipeline
```

## Environment

- See `.xcode-version` for the expected Xcode toolchain.
- See `.ruby-version` for the expected Ruby version

## Commands

```bash
make bootstrap     # Full setup: install gems, lint, test, build debug
make test          # Run swift test
make lint          # SwiftLint + RuboCop (both via Docker)
make lintfix       # Auto-fix lint issues (both via Docker)
make build         # Release build with code signing
make build-debug   # Debug build with development signing
```

`make lint` requires Docker running locally.
Release builds require code-signing certificates via `bundle exec fastlane set_up_signing`.

## Conventions

- **Main branch**: `trunk`
- **Version**: defined in `Sources/libhostmgr/libhostmgr.swift`
- **Release process**: bump version in a PR, merge, push a tag — CI publishes to GitHub Releases
- **SwiftLint**: config in `.swiftlint.yml`
- **RuboCop**: config in `.rubocop.yml`

## Architecture

`hostmgr` (CLI) and `hostmgr-helper` (menu bar app) both depend on `libhostmgr`.
`libhostmgr` uses `tinys3` for S3 operations.

The CLI uses `swift-argument-parser` with subcommands defined in `Sources/hostmgr/`.

The helper app uses SwiftUI.
It also uses Sentry for error tracking.

Key runtime assumption:

- Binaries installed at `/opt/ci/bin/`
- Config lives at `/opt/ci/hostmgr.json`
- VM images stored in `/opt/ci/vm-images/`

## Common Pitfalls

- `make lint` runs SwiftLint and RuboCop in Docker containers — won't work without Docker
- Release builds need signing certificates fetched via Fastlane Match (`bundle exec fastlane set_up_signing`)
- The project targets ARM64 only — no Intel support
- `hostmgr-helper` requires macOS entitlements (`Sources/hostmgr/hostmgr.entitlements`) for Virtualization framework access
- The `vendor/` directory contains bundled Ruby gems — don't modify or commit changes there
