# Changelog

All notable changes to MarchJson are documented in this file.

MarchJson follows Semantic Versioning:

- MAJOR: incompatible command/configuration changes.
- MINOR: backward-compatible features.
- PATCH: backward-compatible fixes.

## [0.3.0] - 2026-10-08

### Added

- Public root installer at install.sh, modeled after march-env distribution workflow.
- Immutable ref resolution: branch or tag is resolved to a commit SHA before runtime download.
- Atomic runtime/version replacement under ~/.local/share/marchjson.
- Automatic ~/.bashrc integration with idempotent MarchJson marker block.
- Installed REVISION file for provenance.
- march-env fingerprint guard during SSH installation.
- Custom MARCHJSON_REPO, MARCHJSON_REF, MARCHJSON_INSTALL_DIR, MARCHJSON_BASHRC, and MARCH_ENV_PATH overrides.

### Changed

- SSH installation no longer requires cloning the repository.
- README installation/update/pinning/isolation flow now follows the same operational pattern as march-env.
- Installer validates Bash syntax, SemVer, downloaded runtime version, installed runtime version, and march-env preservation before reporting PASS.

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
