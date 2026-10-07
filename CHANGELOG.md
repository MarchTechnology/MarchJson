# Changelog

All notable changes to MarchJson are documented in this file.

MarchJson follows Semantic Versioning:

- MAJOR: incompatible command/configuration changes.
- MINOR: backward-compatible features.
- PATCH: backward-compatible fixes.

## [0.2.0] - 2026-10-08

### Added

- Single repository VERSION file as the canonical runtime version source.
- Semantic version commands for PowerShell and Bash.
- Version status sourced dynamically from VERSION.
- SSH installer with explicit march-env coexistence protection.
- SSH coexistence acceptance coverage.

### Changed

- Version output is no longer hardcoded independently in PowerShell and Bash.
- Runtime version falls back to 0.0.0-dev only when VERSION is missing or invalid.

## [0.1.0] - 2026-10-01

### Added

- Initial selective JSON-aware wrapper.
- PowerShell 7 support.
- Bash/SSH support.
- jq pretty-print and ANSI color.
- npm whitelist management.
- curl and node eval wrappers.
- MarchJson/marchjson help, status, list, add, remove, edit, reload, and version commands.
