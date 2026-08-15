# ohnapse/public

Public artifacts for [ohnapse](https://github.com/ohnapse), served at stable URLs for
tools, editors, and the installer to fetch.

## Install the CLI

macOS and Linux:

```sh
brew install ohnapse/tap/ohnapse
```

That auto-taps and trusts this formula. Afterwards `brew upgrade ohnapse` works by
short name. Both `ohnapse` and `oh` land on `PATH`.

```sh
curl -fsSL https://raw.githubusercontent.com/ohnapse/public/main/install.sh | sh
```

The script verifies the sha256 against `checksums.txt`, installs into
`$HOME/.local/bin` (override with `OHNAPSE_INSTALL_DIR`), and symlinks `oh`. Pin a
release with `OHNAPSE_VERSION`.

Windows:

```powershell
irm https://raw.githubusercontent.com/ohnapse/public/main/install.ps1 | iex
```

Manual downloads live on this repo's [Releases](https://github.com/ohnapse/public/releases)
page: `ohnapse_<version>_<os>_<arch>.tar.gz` (`.zip` on Windows), plus `checksums.txt`.
Put `ohnapse` on `PATH` and symlink (or copy) it as `oh`.

The Homebrew formula is maintained in [`ohnapse/homebrew-tap`](https://github.com/ohnapse/homebrew-tap).

## Schemas

### `schemas/ohnapse-settings.schema.json`

JSON Schema (draft 2020-12) for the ohnapse CLI's settings file, `.ohnapse/settings.json`.
`oh init` references it automatically. To add it to an existing config by hand:

```json
{
  "$schema": "https://raw.githubusercontent.com/ohnapse/public/main/schemas/ohnapse-settings.schema.json"
}
```

Any editor that resolves `$schema` — VS Code, JetBrains IDEs, Neovim with a JSON language
server — will then validate keys, complete values, and surface the documentation for each
setting inline.

The schema is closed (`additionalProperties: false`), so an unrecognised key is reported
as an error rather than ignored silently.

## Wiki

`wiki/` holds the ohnapse documentation in MDX. It is the canonical copy — the
documentation site renders it, so a correction here is a correction everywhere.

```
wiki/
├── manifest.json          navigation order
├── index.mdx
├── getting-started/
├── guides/
└── reference/
```

`manifest.json` owns the order pages appear in. Each page carries its own `title` and
`description` in frontmatter, and a page absent from the manifest is not published.

## Issues

ohnapse is in alpha. File bugs, session reports, and docs corrections here:

**[Open an issue](https://github.com/ohnapse/public/issues/new/choose)**

Use a template. Unstructured issues are turned off so every report starts with
`oh version` and an OS. Never paste API keys, tokens, or a `settings.json` that holds
a key — rotate anything that slips through; editing the issue does not un-publish the
history.

---

Contents are published for use with ohnapse; the tool itself is proprietary.
© Kolosys. All rights reserved.
