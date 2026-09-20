<#
.SYNOPSIS
    Run the V2 validation suite.

.DESCRIPTION
    tests_v2/ is the CURRENT validation system. The old tests/ suite is frozen and
    removed and must not be run.

    With no arguments this prints the map and runs nothing, so a full sweep is
    always a deliberate choice. Every suite arms its own timeout and decides its
    own exit code through tests_v2/harness.gd, so this runner waits with -Wait and
    needs no external kill.

    Suites run windowed, not headless: some drive real input and read rendered
    pixels, which a headless run would not exercise.

.PARAMETER Category
    One or more categories: `baseline`, `elevation`, `scenarios`, `lab`.

.PARAMETER Suite
    One or more suite names, with or without .gd, found anywhere under tests_v2/.

.PARAMETER All
    Every suite.

.PARAMETER List
    Print the map and exit.

.PARAMETER Headless
    Pass --headless to Godot. Only safe for suites that touch no viewport.

.PARAMETER GodotPath
    Godot executable. Defaults to $env:GODOT_PATH, then the usual Desktop path,
    then `godot` on PATH.

.EXAMPLE
    .\tests_v2\run.ps1 -Category baseline
.EXAMPLE
    .\tests_v2\run.ps1 -Suite elevation_logic
#>
param(
    [Parameter(Position = 0)]
    [string[]]$Category = @(),

    [string[]]$Suite = @(),
    [switch]$All,
    [switch]$List,
    [switch]$Headless,
    [string]$GodotPath = $env:GODOT_PATH
)

$ErrorActionPreference = 'Stop'
$v2Root = $PSScriptRoot
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $v2Root '..')).ProviderPath

# `pwsh -File run.ps1 -Category a,b` arrives as the single string "a,b".
function Expand-List($values) {
    $out = @()
    foreach ($value in $values) {
        foreach ($part in ($value -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed.Length -gt 0) { $out += $trimmed }
        }
    }
    return $out
}
$Category = Expand-List $Category
$Suite = Expand-List $Suite

# The harness is shared infrastructure, not a suite.
$INFRA = @('harness')

function Get-Categories {
    $names = @()
    foreach ($dir in (Get-ChildItem -LiteralPath $v2Root -Directory | Sort-Object Name)) {
        $names += $dir.Name
    }
    return $names
}

function Get-SuiteIndex {
    $index = @()
    foreach ($category in Get-Categories) {
        $dir = Join-Path $v2Root $category
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter '*.gd' -File | Sort-Object Name)) {
            if ($INFRA -contains $file.BaseName) { continue }
            $index += [pscustomobject]@{ Name = $file.BaseName; Category = $category; Path = $file.FullName }
        }
    }
    return $index
}

function Show-Map {
    Write-Host ''
    Write-Host 'V2 validation suites' -ForegroundColor Cyan
    Write-Host '--------------------'
    $index = Get-SuiteIndex
    if ($index.Count -eq 0) {
        Write-Host '  (none yet)' -ForegroundColor DarkGray
    }
    foreach ($category in Get-Categories) {
        $inCategory = @($index | Where-Object { $_.Category -eq $category })
        if ($inCategory.Count -eq 0) { continue }
        Write-Host ''
        Write-Host ("  {0}" -f $category) -ForegroundColor Yellow
        foreach ($suite in $inCategory) { Write-Host ("    {0}" -f $suite.Name) }
    }
    Write-Host ''
    Write-Host 'Usage:' -ForegroundColor Cyan
    Write-Host '  .\tests_v2\run.ps1 -Category <name>[,<name>]   run a category'
    Write-Host '  .\tests_v2\run.ps1 -Suite <name>[,<name>]      run named suites'
    Write-Host '  .\tests_v2\run.ps1 -All                        every suite'
    Write-Host '  .\tests_v2\run.ps1 -List                       this map'
    Write-Host ''
    Write-Host 'The frozen legacy suite in tests/ must not be run.' -ForegroundColor DarkGray
    Write-Host ''
}

if ($List -or ($Category.Count -eq 0 -and $Suite.Count -eq 0 -and -not $All)) {
    Show-Map
    exit 0
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $desktopCandidate = Join-Path $env:USERPROFILE 'Desktop\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $desktopCandidate) {
        $GodotPath = $desktopCandidate
    } else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $command) { throw 'Godot was not found. Set GODOT_PATH or pass -GodotPath.' }
        $GodotPath = $command.Source
    }
}

$index = Get-SuiteIndex
$selected = @()

if ($All) {
    foreach ($entry in $index) { $selected += $entry }
}
foreach ($name in $Suite) {
    $bare = $name -replace '\.gd$', ''
    $hits = @($index | Where-Object { $_.Name -eq $bare })
    if ($hits.Count -eq 0) { throw "No V2 suite named '$bare'. Try -List." }
    foreach ($h in $hits) { $selected += $h }
}
foreach ($name in $Category) {
    $hits = @($index | Where-Object { $_.Category -eq $name })
    if ($hits.Count -eq 0) {
        throw "Unknown category '$name'. Valid: $((Get-Categories) -join ', ')."
    }
    foreach ($h in $hits) { $selected += $h }
}

$unique = @()
foreach ($entry in $selected) {
    $seen = $false
    foreach ($kept in $unique) { if ($kept.Path -eq $entry.Path) { $seen = $true; break } }
    if (-not $seen) { $unique += $entry }
}
if ($unique.Count -eq 0) { throw 'Nothing selected.' }

$token = [Guid]::NewGuid().ToString('N')
$results = @()

Write-Host ''
Write-Host ("Godot  : {0}" -f $GodotPath) -ForegroundColor DarkGray
Write-Host ("Suites : {0}" -f ($unique.Name -join ', ')) -ForegroundColor Cyan

foreach ($entry in $unique) {
    $relative = $entry.Path.Substring($projectRoot.Length + 1).Replace('\', '/')
    $outPath = Join-Path ([IO.Path]::GetTempPath()) "v2-$token-$($entry.Name).out.log"
    $errPath = Join-Path ([IO.Path]::GetTempPath()) "v2-$token-$($entry.Name).err.log"
    $headlessArg = ''
    if ($Headless) { $headlessArg = '--headless ' }
    $arguments = "--path `"$projectRoot`" $headlessArg--script res://$relative"

    $timer = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments `
        -WindowStyle Hidden -Wait -PassThru `
        -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $timer.Stop()
    $exitCode = $process.ExitCode

    $stdout = ''
    $stderr = ''
    if (Test-Path -LiteralPath $outPath) { $stdout = [string](Get-Content -LiteralPath $outPath -Raw -ErrorAction SilentlyContinue) }
    if (Test-Path -LiteralPath $errPath) { $stderr = [string](Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue) }
    Remove-Item -LiteralPath $outPath, $errPath -Force -ErrorAction SilentlyContinue

    $status = 'FAIL'
    $colour = 'Red'
    if ($exitCode -eq 0) { $status = 'PASS'; $colour = 'Green' }

    Write-Host ''
    Write-Host ("[{0}] {1}  ({2:n1}s)" -f $status, $entry.Name, $timer.Elapsed.TotalSeconds) -ForegroundColor $colour
    foreach ($line in ($stdout -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) { continue }
        if ($line -notmatch 'Godot Engine v|OpenGL API|Vulkan API') {
            if ($line -match '^\s+\S' -or $line -match '^V2 ') {
                Write-Host ("    {0}" -f $trimmed) -ForegroundColor DarkGray
            }
        }
    }
    if ($status -ne 'PASS') {
        foreach ($line in ($stderr -split "`r?`n")) {
            if ($line.Trim().Length -gt 0) { Write-Host ("    {0}" -f $line.TrimEnd()) -ForegroundColor Gray }
        }
    }

    $results += [pscustomobject]@{ Suite = $entry.Name; Status = $status; Seconds = $timer.Elapsed.TotalSeconds }
}

$failed = @($results | Where-Object { $_.Status -ne 'PASS' })
$total = 0.0
foreach ($r in $results) { $total += $r.Seconds }

Write-Host ''
if ($failed.Count -eq 0) {
    Write-Host ("{0}/{1} passed in {2:n1}s" -f $results.Count, $results.Count, $total) -ForegroundColor Green
    exit 0
}
Write-Host ("{0}/{1} passed in {2:n1}s" -f ($results.Count - $failed.Count), $results.Count, $total) -ForegroundColor Red
foreach ($r in $failed) { Write-Host ("  FAIL  {0}" -f $r.Suite) -ForegroundColor Red }
exit 1
