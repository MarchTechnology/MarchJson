# MarchJson Milestone

## P.0.1 — Initial selective JSON wrapper

Status: **Implemented**

### Scope

- PowerShell 7 wrapper.
- Bash/SSH wrapper.
- Pretty JSON through jq.
- ANSI color through jq -C.
- curl wrapper with native bypass for file-transfer modes.
- npm run whitelist.
- node eval wrapper.
- Dynamic whitelist file.
- Short command aliases.
- Status/help/version commands.
- FNM-safe native command resolution on PowerShell.
- Solar-PuTTY/cPanel compatibility through Bash.
- SSH installer with idempotent ~/.bashrc integration.
- Explicit coexistence guard for ~/.local/bin/march-env.
- SSH install acceptance test proving march-env fingerprint preservation and idempotent marker handling.

### Command surface

PowerShell:

~~~text
MarchJson -h
MarchJson h
MarchJson s
MarchJson l
MarchJson a <script>
MarchJson r <script>
MarchJson e
MarchJson rl
MarchJson v
~~~

Bash:

~~~text
marchjson -h
marchjson h
marchjson s
marchjson l
marchjson a <script>
marchjson r <script>
marchjson e
marchjson rl
marchjson v
~~~

### Known limitations

- Selected wrappers buffer command output until process completion.
- Long-running npm scripts must not be whitelisted.
- JSON multiline embedded inside mixed logs is not reconstructed across multiple lines.
- PowerShell node stderr behavior can vary by native-command stream handling; status and bypass commands are provided for diagnosis.
- curl auto-formatting is intended for text/JSON responses, not arbitrary binary stdout.

## P.0.2 — Semantic versioning foundation

Status: **Implemented**

### Scope

- Canonical VERSION file.
- Current version: 0.2.0.
- SemVer validation.
- Dynamic version loading in PowerShell and Bash.
- MarchJson -v / --version / v / version.
- marchjson -v / --version / v / version.
- Version file path included in status output.
- CHANGELOG.md.
- Bash and PowerShell version setter scripts.
- Bash acceptance for version source and command output.
- Runtime fallback to 0.0.0-dev when VERSION is missing or invalid.

### Release invariant

- VERSION is the only canonical release version source.
- Runtime files must not carry an independent hardcoded release version.
- Releases use Git tags in the form vMAJOR.MINOR.PATCH.
- CHANGELOG.md must be updated for each release.
- Version acceptance must pass before release tagging.

## P.0.3 — Planned

- PowerShell installer/bootstrap script.
- SSH uninstall/restore helper.
- PowerShell uninstall/restore helper.
- Automated syntax validation.
- Fixture-based tests for:
  - pure JSON stdout;
  - JSON stderr;
  - mixed log + JSON line;
  - non-JSON output;
  - non-zero exit codes;
  - FNM path changes.
- Config file for wrapper enable/disable settings.
- Optional per-command whitelist beyond npm scripts.
- Improved mixed-stream ordering.

## SSH coexistence invariant

- MarchJson runtime lives under ~/.local/share/marchjson.
- march-env remains under ~/.local/bin/march-env.
- MarchJson installer must never replace, chmod, move, or delete march-env.
- MarchJson installer must never clear or recreate ~/.local/bin.
- Changes to ~/.bashrc must be scoped to the MarchJson marker block and must preserve unrelated configuration.
- Acceptance must verify march-env content is byte-for-byte unchanged across repeated installs.

## Repository policy

- No GitHub Actions unless there is a concrete need.
- Keep runtime dependencies minimal.
- Prefer explicit bypass paths over hidden global interception.
- Preserve native behavior for interactive and streaming commands.
