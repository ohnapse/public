# Install ohnapse (and the oh alias) from GitHub Releases.
# Usage: irm https://raw.githubusercontent.com/ohnapse/public/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # Older hosts already negotiate TLS 1.2; ignore if the flag cannot be set.
}

$Repo = 'ohnapse/public'
$Api = "https://api.github.com/repos/$Repo"
$Download = "https://github.com/$Repo/releases/download"
$Headers = @{
    'User-Agent' = 'ohnapse-install'
    'Accept'     = 'application/vnd.github+json'
}

function Die([string]$Message) {
    throw "install.ps1: $Message"
}

$arch = switch -Regex ($env:PROCESSOR_ARCHITECTURE) {
    'ARM64' { 'arm64'; break }
    'AMD64' { 'amd64'; break }
    default { Die "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
}

$dest = if ($env:OHNAPSE_INSTALL_DIR -and $env:OHNAPSE_INSTALL_DIR.Trim()) {
    $env:OHNAPSE_INSTALL_DIR
} else {
    Join-Path $HOME '.local\bin'
}

function Resolve-Tag {
    if ($env:OHNAPSE_VERSION -and $env:OHNAPSE_VERSION.Trim()) {
        $ver = $env:OHNAPSE_VERSION.Trim().TrimStart('v')
        return "v$ver"
    }
    try {
        $rel = Invoke-RestMethod -Headers $Headers -Uri "$Api/releases/latest"
    } catch {
        $rels = Invoke-RestMethod -Headers $Headers -Uri "$Api/releases?per_page=1"
        if (-not $rels) {
            Die "could not resolve the latest release from $Repo"
        }
        $rel = @($rels)[0]
    }
    if (-not $rel.tag_name) {
        Die 'could not parse tag_name from the GitHub API'
    }
    $ver = $rel.tag_name.TrimStart('v')
    return "v$ver"
}

function Get-Checksum([string]$File, [string]$SumsPath) {
    foreach ($line in Get-Content -Path $SumsPath) {
        if ($line -notmatch '^\s*([0-9A-Fa-f]+)\s+\*?(\S+)\s*$') {
            continue
        }
        if ($Matches[2] -eq $File) {
            return $Matches[1].ToLowerInvariant()
        }
    }
    Die "checksums.txt has no entry for $File"
}

$tag = Resolve-Tag
$ver = $tag.TrimStart('v')
$archive = "ohnapse_${ver}_windows_${arch}.zip"
$base = "$Download/$tag"

$tmpdir = Join-Path ([System.IO.Path]::GetTempPath()) ("ohnapse-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $tmpdir | Out-Null
try {
    Write-Host "install.ps1: fetching $archive"
    $sumsPath = Join-Path $tmpdir 'checksums.txt'
    $zipPath = Join-Path $tmpdir $archive
    Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent' = 'ohnapse-install' } -Uri "$base/checksums.txt" -OutFile $sumsPath
    Invoke-WebRequest -UseBasicParsing -Headers @{ 'User-Agent' = 'ohnapse-install' } -Uri "$base/$archive" -OutFile $zipPath

    $expected = Get-Checksum -File $archive -SumsPath $sumsPath
    $actual = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLowerInvariant()
    if ($expected -ne $actual) {
        Die "sha256 mismatch for $archive (want $expected, got $actual)"
    }

    Expand-Archive -Path $zipPath -DestinationPath $tmpdir -Force
    $binfile = @(
        Join-Path $tmpdir 'ohnapse.exe'
        Join-Path $tmpdir 'ohnapse'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $binfile) {
        Die "archive $archive did not contain an ohnapse binary"
    }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $target = Join-Path $dest 'ohnapse.exe'
    Copy-Item -LiteralPath $binfile -Destination $target -Force
    $alias = Join-Path $dest 'oh.exe'
    Copy-Item -LiteralPath $target -Destination $alias -Force

    Write-Host "install.ps1: installed $target and $alias"

    $pathEntries = $env:PATH -split ';' | ForEach-Object { $_.TrimEnd('\') }
    $destNorm = $dest.TrimEnd('\')
    if ($pathEntries -notcontains $destNorm) {
        Write-Warning "install.ps1: $dest is not on PATH"
        Write-Host "install.ps1: add this directory to your user PATH, for example:"
        Write-Host "  [Environment]::SetEnvironmentVariable('Path', `"$dest;$([Environment]::GetEnvironmentVariable('Path','User'))`", 'User')"
    }
} finally {
    Remove-Item -LiteralPath $tmpdir -Recurse -Force -ErrorAction SilentlyContinue
}
