# vitrina_1c build.ps1 — Build EPF from sources
param([string]$RepoDir = $PSScriptRoot)

$ErrorActionPreference = 'Stop'

try {
    # Install v8unpack if missing
    $pkg = pip list 2>$null | Select-String "v8unpack"
    if (-not $pkg) {
        Write-Host "Установка v8unpack..." -ForegroundColor Yellow
        pip install v8unpack
    }

    Write-Host "Сборка vitrina_export.epf..." -ForegroundColor Green
    python "$RepoDir\build_epf.py" "$RepoDir"

    Write-Host "Сборка test_runner.epf..." -ForegroundColor Green
    python "$RepoDir\build_epf.py" "--src" "$RepoDir\tests\test_runner" "--out" "$RepoDir\test_runner.epf"

    @("vitrina_export.epf", "test_runner.epf") | ForEach-Object {
        $epf = Join-Path $RepoDir $_
        if (Test-Path $epf) {
            Write-Host "  OK: $epf" -ForegroundColor Green
        } else {
            throw "$_ не создан!"
        }
    }
}
catch {
    Write-Host "ОШИБКА: $_" -ForegroundColor Red
    exit 1
}