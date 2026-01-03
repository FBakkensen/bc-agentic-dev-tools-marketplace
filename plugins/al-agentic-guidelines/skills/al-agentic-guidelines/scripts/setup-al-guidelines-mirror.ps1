[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/microsoft/alguidelines.git",
    [string]$TargetPath = "_aldoc\al-guidelines",
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    param(
        [string]$ProvidedRoot,
        [string]$ScriptRoot
    )

    if ($ProvidedRoot) {
        return (Resolve-Path $ProvidedRoot).Path
    }

    $cwd = (Get-Location).Path
    if (Test-Path (Join-Path $cwd ".git")) {
        return (Resolve-Path $cwd).Path
    }

    $candidate = Resolve-Path (Join-Path $ScriptRoot "..\..\..\..") -ErrorAction SilentlyContinue
    if ($candidate -and (Test-Path (Join-Path $candidate ".git"))) {
        return $candidate.Path
    }

    throw "Repo root not found. Run from the repo root or pass -RepoRoot."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git not found in PATH. Install git or add it to PATH."
}

$repoRoot = Resolve-RepoRoot -ProvidedRoot $RepoRoot -ScriptRoot $PSScriptRoot
$repoRootFull = [IO.Path]::GetFullPath($repoRoot)
$baseRoot = Split-Path $repoRootFull -Parent
if ([IO.Path]::IsPathRooted($TargetPath)) {
    $dest = $TargetPath
} else {
    $dest = Join-Path $baseRoot $TargetPath
}
$dest = [IO.Path]::GetFullPath($dest)
$destParent = Split-Path $dest -Parent

if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Force -Path $destParent | Out-Null
    & git clone $RepoUrl $dest
} else {
    Write-Host "Repo already exists: $dest"
}

Write-Host "al-guidelines ready at $dest"
