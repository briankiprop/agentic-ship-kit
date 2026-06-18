# Global installer for the Agentic Ship Kit on Windows PowerShell.
#
# Install (run once on your machine):
#   irm https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap-global.ps1 | iex
#
# After running, open ANY project in Claude Code and type:
#   /ship-skit Your task here

param(
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$Repo = if ($env:ASK_REPO) { $env:ASK_REPO } else { 'https://github.com/briankiprop/agentic-ship-kit.git' }
$Ref  = if ($env:ASK_REF)  { $env:ASK_REF  } else { 'main' }
$GlobalDir = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE '.claude' }

Write-Host "Agentic Ship Kit - Source: $Repo@$Ref"

# Check git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is required but was not found. Install Git from https://git-scm.com"
    exit 1
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) "agentic-ship-kit-$(Get-Random)"
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    git clone --depth 1 --branch $Ref $Repo "$Tmp\kit" 2>$null
    if (-not $?) { throw "Failed to clone $Repo@$Ref" }

    function Backup-AndCopy($Src, $Dest) {
        if (Test-Path $Dest) {
            $stamp = Get-Date -Format 'yyyyMMddHHmmss'
            $backup = "$Dest.agentic-ship-backup.$stamp"
            Write-Host "  Backing up $Dest -> $backup"
            Move-Item $Dest $backup
        }
        $parent = Split-Path $Dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -Recurse $Src $Dest
        Write-Host "  Installed $($Dest.Replace($GlobalDir, '').TrimStart('\/'))"
    }

    Backup-AndCopy "$Tmp\kit\.claude\skills\ship-skit" (Join-Path $GlobalDir 'skills\ship-skit')
    Backup-AndCopy "$Tmp\kit\.claude\agents"           (Join-Path $GlobalDir 'agents')
    Backup-AndCopy "$Tmp\kit\.claude\rules"            (Join-Path $GlobalDir 'rules')

    Write-Host ""
    Write-Host "Done! The kit is now available in every project you open in Claude Code."
    Write-Host ""
    Write-Host "How to use it:"
    Write-Host "  1. Open any project in Claude Code"
    Write-Host "  2. Type:  /ship-skit Your task here"
    Write-Host "  3. Example: /ship-skit add a login page with email and password"
}
finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
