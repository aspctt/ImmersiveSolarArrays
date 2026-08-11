<#
    Static checks for Immersive Solar Arrays.

    Two passes:
      1. Compile every mod Lua file with the Kahlua compiler out of projectzomboid.jar,
         which is the same parser the game uses, so a syntax error surfaces here.
      2. Cross-reference the mod against the installed build: translation keys, texture
         paths, item script fields, recipe inputs and hooks, sandbox options, requires.

    Usage:  pwsh tests/run-checks.ps1
    Set ISA_PZ_DIR to point at an install this does not find on its own.
#>

$ErrorActionPreference = 'Stop'

function Find-GameDir {
    if ($env:ISA_PZ_DIR) { return $env:ISA_PZ_DIR }

    $candidates = @()
    foreach ($steam in @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam")) {
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
                $candidates += Join-Path ($m.Groups[1].Value -replace '\\\\', '\') 'steamapps\common\ProjectZomboid'
            }
        }
    }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Name) {
        $candidates += "${drive}:\SteamLibrary\steamapps\common\ProjectZomboid"
        $candidates += "${drive}:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    }

    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'projectzomboid.jar')) { return $c }
    }
    throw "Could not find a Project Zomboid install. Set ISA_PZ_DIR to its folder."
}

function Find-Jdk {
    # The JRE the game ships cannot compile, so a real JDK is needed for the Lua pass.
    $patterns = @(
        'C:\Program Files\Eclipse Adoptium\jdk-*\bin',
        'C:\Program Files\*\jdk*\bin',
        'C:\Program Files\JetBrains\*\jbr\bin'
    )
    foreach ($pattern in $patterns) {
        $hit = Get-ChildItem $pattern -ErrorAction SilentlyContinue |
               Where-Object { Test-Path (Join-Path $_.FullName 'javac.exe') } |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    throw "No JDK with javac found."
}

$GameDir = Find-GameDir
$Jar     = Join-Path $GameDir 'projectzomboid.jar'
$Root    = Split-Path -Parent $PSScriptRoot
$Harness = Join-Path $PSScriptRoot 'harness'
$Build   = Join-Path $PSScriptRoot 'build'

$ModRoots = @(
    Join-Path $Root 'Immersive Solar Arrays\mods\ImmersiveSolarArrays\42'
    Join-Path $Root 'Immersive Solar Arrays\mods\ImmersiveSolarArrays\common'
) | Where-Object { Test-Path $_ }

$VersionFile = Join-Path $env:USERPROFILE 'Zomboid\version.txt'
$Build42 = if (Test-Path $VersionFile) { (Get-Content $VersionFile | Select-Object -First 1) } else { 'unknown' }

Write-Host "Game    $GameDir"
Write-Host "Build   $Build42"
Write-Host ""

# --- pass 1: does the game's own compiler accept every file ------------------

$JdkBin = Find-Jdk
$Javac  = Join-Path $JdkBin 'javac.exe'
$Java   = Join-Path $JdkBin 'java.exe'

New-Item -ItemType Directory -Force -Path $Build | Out-Null

function Build-Tool([string]$Name) {
    $src = Join-Path $Harness "$Name.java"
    $cls = Join-Path $Build "$Name.class"
    if (-not (Test-Path $cls) -or (Get-Item $src).LastWriteTime -gt (Get-Item $cls).LastWriteTime) {
        & $Javac -nowarn -cp $Jar -d $Build $src
        if ($LASTEXITCODE -ne 0) { throw "Failed to compile $Name.java" }
    }
}

Build-Tool 'CheckLua'
Build-Tool 'DumpApi'

# The list of method names the engine exposes, rebuilt whenever the game updates. The
# cross-reference pass checks every `:name(` in the mod against it.
$ApiNames = Join-Path $Build 'api-names.txt'
if (-not (Test-Path $ApiNames) -or (Get-Item $Jar).LastWriteTime -gt (Get-Item $ApiNames).LastWriteTime) {
    & $Java -cp "$Build;$Jar" DumpApi $Jar $ApiNames
    if ($LASTEXITCODE -ne 0) { throw "Failed to dump the game API" }
}

$LuaFiles = $ModRoots |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem $_ -Filter *.lua -Recurse -File } |
    ForEach-Object { $_.FullName } |
    Sort-Object

$ListFile = Join-Path $Build 'lua-files.txt'
Set-Content -Path $ListFile -Value $LuaFiles -Encoding UTF8

# Kahlua resolves stdlib.lua relative to the working directory, so run from the game dir.
Push-Location $GameDir
try {
    & $Java -cp "$Build;$Jar" CheckLua "@$ListFile"
    $luaExit = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Host ""

# --- pass 2: cross-reference against the installed build ---------------------

$python = (Get-Command python -ErrorAction SilentlyContinue) ??
          (Get-Command python3 -ErrorAction SilentlyContinue)
if (-not $python) { throw "Python is required for the cross-reference pass." }

& $python.Source (Join-Path $Harness 'check.py') $GameDir @ModRoots
$checkExit = $LASTEXITCODE

exit ([Math]::Max($luaExit, $checkExit))
