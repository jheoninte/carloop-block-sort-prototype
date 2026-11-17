param(
    [ValidateSet("play", "editor", "import", "test", "levels", "pacing", "playtest", "campaign")]
    [string]$Action = "play",
    [string]$PackPath,
    [string]$LevelId = "level-001",
    [ValidateSet(1, 2)]
    [int]$Speed = 1
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$engineFolder = Join-Path $projectRoot ".tools/godot"
$enginePath = $null
if (Test-Path -LiteralPath $engineFolder) {
    $bundled = Get-ChildItem -LiteralPath $engineFolder -Filter "*_console.exe" | Select-Object -First 1
    if ($null -ne $bundled) {
        $enginePath = $bundled.FullName
    }
}
if ($null -eq $enginePath) {
    $installed = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $installed) {
        $enginePath = $installed.Source
    }
}
if ($null -eq $enginePath) {
    throw "Godot 4.7.2 is required. Add it to PATH or extract the official Windows archive into .tools/godot."
}
$engineArguments = @("--path", (Join-Path $projectRoot "godot-project"))
switch ($Action) {
    "editor" { $engineArguments += "--editor" }
    "import" { $engineArguments += @("--headless", "--editor", "--import", "--quit") }
    "test" { $engineArguments += @("--headless", "--script", "scripts/HeadlessTest.gd") }
    "playtest" { $engineArguments += @("--script", "scripts/PlaytestRunner.gd", "--", "--level", $LevelId, "--speed", "$Speed") }
    "campaign" {
        $candidatePath = Join-Path $projectRoot ".tools/campaign-300.json"
        $engineArguments += @("--headless", "--script", "scripts/CampaignBuilder.gd", "--", "--pack", $candidatePath)
    }
    "pacing" {
        $reportPath = Join-Path $projectRoot "docs/PLAYTEST_BASELINE.md"
        $engineArguments += @("--headless", "--script", "scripts/LevelPacingCheck.gd", "--", "--report", $reportPath)
    }
    "levels" {
        $engineArguments += @("--headless", "--script", "scripts/LevelPackCheck.gd")
        if ($PackPath) {
            $candidatePath = (Resolve-Path -LiteralPath $PackPath).Path
            $engineArguments += @("--", "--pack", $candidatePath)
        }
    }
}
& $enginePath @engineArguments
$engineExitCode = $LASTEXITCODE
if ($Action -eq "test" -and $engineExitCode -eq 0) {
    & $enginePath --path (Join-Path $projectRoot "godot-project") --headless --script scripts/CommerceTest.gd
    $engineExitCode = $LASTEXITCODE
}
if ($Action -eq "test" -and $engineExitCode -eq 0) {
    & $enginePath --path (Join-Path $projectRoot "godot-project") --headless --script scripts/MigrationTest.gd
    $engineExitCode = $LASTEXITCODE
}
if ($Action -eq "test" -and $engineExitCode -eq 0) {
    & $enginePath --path (Join-Path $projectRoot "godot-project") --headless --script scripts/LevelPackCheck.gd
    $engineExitCode = $LASTEXITCODE
}
exit $engineExitCode
