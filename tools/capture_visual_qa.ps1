param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('main_menu', 'main_menu_focus', 'main_menu_pressed', 'menu_transition', 'classic_entry', 'town_overview', 'village', 'wilderness', 'enemy_camp', 'combat', 'merchant_shop', 'dialogue_ui', 'pause_menu', 'reward_overlay', 'shop_overlay', 'result_dead')]
    [string]$Target,

    [string]$Output = '',
    [string]$GodotPath = $env:GODOT_PATH
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($Output)) {
    $Output = "res://screenshots/visual_qa/$Target.png"
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $desktopCandidate = Join-Path $env:USERPROFILE 'Desktop\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $desktopCandidate) {
        $GodotPath = $desktopCandidate
    } else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            throw 'Godot was not found. Set GODOT_PATH or pass -GodotPath.'
        }
        $GodotPath = $command.Source
    }
}

$token = [Guid]::NewGuid().ToString('N')
$stdoutPath = Join-Path ([IO.Path]::GetTempPath()) "godot-visual-qa-$token.stdout.log"
$stderrPath = Join-Path ([IO.Path]::GetTempPath()) "godot-visual-qa-$token.stderr.log"
try {
    $arguments = "--path `"$projectRoot`" --script res://tools/visual_qa_capture.gd -- --target $Target --output `"$Output`""
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments `
        -WindowStyle Hidden -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $stdout = Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { Write-Host $stdout.TrimEnd() }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Error $stderr.TrimEnd() }
    if ($process.ExitCode -ne 0) {
        throw "Godot visual QA capture failed with exit code $($process.ExitCode)."
    }
} finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}