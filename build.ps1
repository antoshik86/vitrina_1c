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

    Write-Host "Сборка EPF..." -ForegroundColor Green
    python "$RepoDir\build_epf.py" "$RepoDir"

    $epf = Join-Path $RepoDir "vitrina_export.epf"
    if (Test-Path $epf) {
        Write-Host "Готово: $epf" -ForegroundColor Green
    } else {
        throw "EPF не создан!"
    }
}
catch {
    Write-Host "ОШИБКА: $_" -ForegroundColor Red
    exit 1
}