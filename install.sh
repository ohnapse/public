#!/bin/sh
# Install ohnapse (and the oh alias) from GitHub Releases.
# Usage: curl -fsSL https://raw.githubusercontent.com/ohnapse/public/main/install.sh | sh
set -eu

REPO="ohnapse/public"
API="https://api.github.com/repos/${REPO}"
DOWNLOAD="https://github.com/${REPO}/releases/download"
UA="ohnapse-install"

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "need ${1} on PATH"
}

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$os" in
  linux) os=linux ;;
  darwin) os=darwin ;;
  msys*|mingw*|cygwin*)
    die "Windows is not supported by this script; use install.ps1"
    ;;
  *)
    die "unsupported OS: $(uname -s)"
    ;;
esac

arch=$(uname -m)
case "$arch" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *)
    die "unsupported architecture: $(uname -m)"
    ;;
esac

need curl
need tar
need awk
need sed

ext=tar.gz
dest=${OHNAPSE_INSTALL_DIR:-"${HOME}/.local/bin"}

github_get() {
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: ${UA}" \
    "$1"
}

resolve_tag() {
  if [ -n "${OHNAPSE_VERSION:-}" ]; then
    ver=${OHNAPSE_VERSION#v}
    printf 'v%s\n' "$ver"
    return
  fi
  json=$(github_get "${API}/releases/latest") || json=$(github_get "${API}/releases?per_page=1") ||
    die "could not resolve the latest release from ${REPO}"
  tag=$(printf '%s\n' "$json" | sed -n 's/^[[:space:]]*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$tag" ] || die "could not parse tag_name from the GitHub API"
  ver=${tag#v}
  printf 'v%s\n' "$ver"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "need sha256sum or shasum"
  fi
}

sum_for() {
  file=$1
  sums=$2
  sum=$(awk -v f="$file" '
    {
      name = $2
      sub(/^\*/, "", name)
      if (name == f) { print $1; exit }
    }
  ' "$sums")
  [ -n "$sum" ] || die "checksums.txt has no entry for ${file}"
  printf '%s\n' "$sum"
}

tag=$(resolve_tag)
ver=${tag#v}
archive="ohnapse_${ver}_${os}_${arch}.${ext}"
base="${DOWNLOAD}/${tag}"

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ohnapse.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

printf 'install.sh: fetching %s\n' "$archive" >&2
curl -fsSL -H "User-Agent: ${UA}" -o "${tmpdir}/checksums.txt" "${base}/checksums.txt" ||
  die "failed to download checksums.txt from ${base}"
curl -fsSL -H "User-Agent: ${UA}" -o "${tmpdir}/${archive}" "${base}/${archive}" ||
  die "failed to download ${archive} from ${base}"

expected=$(sum_for "$archive" "${tmpdir}/checksums.txt")
actual=$(sha256_of "${tmpdir}/${archive}")
expected=$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')
actual=$(printf '%s' "$actual" | tr '[:upper:]' '[:lower:]')
[ "$expected" = "$actual" ] || die "sha256 mismatch for ${archive} (want ${expected}, got ${actual})"

tar -xzf "${tmpdir}/${archive}" -C "$tmpdir"
binfile=
for cand in "${tmpdir}/ohnapse" "${tmpdir}/ohnapse.exe"; do
  if [ -f "$cand" ]; then
    binfile=$cand
    break
  fi
done
[ -n "$binfile" ] || die "archive ${archive} did not contain an ohnapse binary"

mkdir -p "$dest"
cp "$binfile" "${dest}/ohnapse"
chmod 755 "${dest}/ohnapse"
ln -sfn ohnapse "${dest}/oh"

printf 'install.sh: installed %s and %s\n' "${dest}/ohnapse" "${dest}/oh" >&2

case ":${PATH}:" in
  *":${dest}:"*) ;;
  *)
    printf 'install.sh: warning: %s is not on PATH\n' "$dest" >&2
    printf 'install.sh: add this line to your shell profile:\n' >&2
    printf '  export PATH="%s:$PATH"\n' "$dest" >&2
    ;;
esac
