# Runner distribution

Published binaries for [Runner](https://github.com/hap-team/runner). This
repository holds no source — only releases, their checksums, and the installer.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/cajoy/runner-dist/main/install.sh | sh
runner version
```

Pin a version, or register the MCP server with Claude Code and Codex:

```bash
curl -fsSL .../install.sh | sh -s -- v0.8.14
curl -fsSL .../install.sh | sh -s -- --with-mcp
```

The installer verifies the binary against the release's `checksums.txt` before
installing it to `~/.local/bin`, and refuses to install on a mismatch.

It installs nothing else. A task that declares no `runtime: host` runs in a
container, so the installer ends with a note when no engine is reachable —
a note and not a failure, because Runner itself does not need one.

## What a release contains

| | |
| --- | --- |
| `runner_<version>_<os>_<arch>` | the Runner binary |
| `runner-plugin-<name>_<version>_<os>_<arch>` | provider plugins, when a release ships them |
| `checksums.txt` | SHA-256 for every artifact |
| `manifest.json` | the toolchain catalog a project pins from |
| `install.sh` | this installer |

Platforms: `darwin/arm64`, `linux/amd64`, `linux/arm64`.

## Projects pin a version

A repository using Runner commits `.local-ci/toolchain.lock`, which names the
exact version and the SHA-256 of every artifact. The first `runner run` on a
machine downloads exactly what that lock names and verifies each byte against
it, so a project's toolchain is reproducible and does not depend on what
happens to be installed.

See [cajoy/runner-demo](https://github.com/cajoy/runner-demo) for a worked
example.
