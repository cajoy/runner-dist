#!/usr/bin/env sh

# Install Runner from its public distribution repository.
#
#   curl -fsSL https://github.com/cajoy/runner-dist/releases/latest/download/install.sh | sh
#
# Runner's source is private; this installs a published, checksummed binary.
# Pass a version to pin one:  ... | sh -s -- v0.8.12
# Register MCP servers too:   ... | sh -s -- --with-mcp

set -eu

repository=${RUNNER_DIST_REPOSITORY:-cajoy/runner-dist}
install_dir=${RUNNER_INSTALL_DIR:-$HOME/.local/bin}
version=""
with_mcp=0

for argument in "$@"; do
  case $argument in
    --with-mcp) with_mcp=1 ;;
    --help|-h)
      echo "usage: install.sh [version] [--with-mcp]"
      exit 0
      ;;
    v*) version=$argument ;;
    *)
      echo "install_argument_invalid: $argument" >&2
      exit 2
      ;;
  esac
done

case $(uname -s) in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  *) echo "install_platform_unsupported: $(uname -s)" >&2; exit 2 ;;
esac
case $(uname -m) in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64) arch=amd64 ;;
  *) echo "install_platform_unsupported: $(uname -m)" >&2; exit 2 ;;
esac
if [ "$os" = darwin ] && [ "$arch" = amd64 ]; then
  echo "install_platform_unsupported: darwin/amd64" >&2
  exit 2
fi

for tool in curl uname; do
  command -v "$tool" >/dev/null 2>&1 || { echo "install_tool_missing: $tool" >&2; exit 2; }
done
if command -v shasum >/dev/null 2>&1; then
  checksum() { shasum -a 256 "$1" | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null 2>&1; then
  checksum() { sha256sum "$1" | cut -d' ' -f1; }
else
  echo "install_tool_missing: shasum or sha256sum" >&2
  exit 2
fi

host=${RUNNER_DOWNLOAD_BASE_URL:-https://github.com}
if [ -n "$version" ]; then
  base="$host/$repository/releases/download/$version"
else
  base="$host/$repository/releases/latest/download"
fi
asset_dir=$(mktemp -d)
cleanup() { rm -rf "$asset_dir"; }
trap cleanup EXIT INT TERM

# The version is only known after the download when "latest" was used, so the
# asset name is resolved from the checksums file the release publishes.
echo "downloading Runner from $repository ..." >&2
curl -fsSL "$base/checksums.txt" -o "$asset_dir/checksums.txt" ||
  { echo "install_release_unavailable: $base" >&2; exit 2; }

asset=$(grep -o "runner_[^ ]*_${os}_${arch}\$" "$asset_dir/checksums.txt" | head -1)
if [ -z "$asset" ]; then
  echo "install_asset_missing: ${os}_${arch}" >&2
  exit 2
fi
expected=$(grep " $asset\$" "$asset_dir/checksums.txt" | cut -d' ' -f1)
if [ -z "$expected" ]; then
  echo "install_checksum_missing: $asset" >&2
  exit 2
fi

curl -fsSL "$base/$asset" -o "$asset_dir/runner" ||
  { echo "install_download_failed: $base/$asset" >&2; exit 2; }

actual=$(checksum "$asset_dir/runner")
if [ "$actual" != "$expected" ]; then
  echo "install_checksum_mismatch: $asset" >&2
  echo "  expected $expected" >&2
  echo "  actual   $actual" >&2
  exit 2
fi

mkdir -p "$install_dir"
chmod 0755 "$asset_dir/runner"
mv "$asset_dir/runner" "$install_dir/runner"
echo "installed $install_dir/runner ($("$install_dir/runner" version))" >&2

if [ "$with_mcp" -eq 1 ]; then
  # Register the binary by absolute path: an MCP client launches it directly,
  # with no shell and no PATH of its own.
  if command -v claude >/dev/null 2>&1; then
    claude mcp add runner -- "$install_dir/runner" mcp >/dev/null 2>&1 &&
      echo "registered the Runner MCP server with Claude Code" >&2 ||
      echo "claude mcp add failed; register manually with: claude mcp add runner -- $install_dir/runner mcp" >&2
  fi
  if command -v codex >/dev/null 2>&1; then
    codex mcp add runner -- "$install_dir/runner" mcp >/dev/null 2>&1 &&
      echo "registered the Runner MCP server with Codex" >&2 ||
      echo "codex mcp add failed; register manually with: codex mcp add runner -- $install_dir/runner mcp" >&2
  fi
fi

case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) echo "note: $install_dir is not on PATH" >&2 ;;
esac
