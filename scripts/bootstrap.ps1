# One-line installer for the Agentic Ship Kit (Windows / PowerShell).
#
# Run this from inside the project you want to add the kit to:
#
#   irm https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.ps1 | iex
#
# It clones the kit into a temp directory and copies its files into the current
# directory. Existing files are backed up, not overwritten.
#
# NOTE: the kit's workflow runs bash scripts at runtime (the Stop hook runs
# `bash scripts/checkpoint.sh`, and /ship calls scripts/create-run.sh), so you
# still need Git Bash or WSL installed to *run* the workflow. This installer
# only places the files.

$ErrorActionPreference = "Stop"

$Repo = if ($env:ASK_REPO) { $env:ASK_REPO } else { "https://github.com/briankiprop/agentic-ship-kit.git" }
$Ref  = if ($env:ASK_REF)  { $env:ASK_REF }  else { "main" }
$Target = (Get-Location).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is required but was not found on PATH."
    exit 1
}

Write-Host "Installing Agentic Ship Kit into: $Target"
Write-Host "Source: $Repo@$Ref"

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ask-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

try {
    # Do not redirect git's stderr: in Windows PowerShell that wraps git's
    # normal "Cloning into..." progress as an error and trips ErrorAction Stop.
    # git writes progress to stderr even on success, so check $LASTEXITCODE.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    git clone --depth 1 --branch $Ref $Repo (Join-Path $Tmp "kit")
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "Failed to clone $Repo@$Ref" }

    $Kit = Join-Path $Tmp "kit"
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    foreach ($item in @(".claude", "AGENTS.md", "CLAUDE.md", "templates", "scripts")) {
        $src  = Join-Path $Kit $item
        $dest = Join-Path $Target $item
        if (Test-Path $dest) {
            $backup = "$dest.agentic-ship-backup.$stamp"
            Write-Host "Backing up existing $dest to $backup"
            Move-Item -Path $dest -Destination $backup
        }
        Copy-Item -Path $src -Destination $dest -Recurse
    }

    Write-Host ""
    Write-Host "Installed Agentic Ship Kit into: $Target"
    Write-Host ""
    Write-Host "The workflow runs bash scripts, so install Git Bash or WSL if you do not have it."
    Write-Host "Then open this project in Claude Code and run:"
    Write-Host "  /ship Your task here"
}
finally {
    Remove-Item -Path $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
