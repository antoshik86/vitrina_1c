# vitrina_1c build.ps1 — сборка EPF из исходников (нужен Python)
param([string]$RepoDir = $PSScriptRoot)

$ErrorActionPreference = 'Stop'

try {
    $pkg = pip list 2>$null | Select-String "v8unpack"
    if (-not $pkg) {
        Write-Host "Установка v8unpack..." -ForegroundColor Yellow
        pip install v8unpack
    }

    Write-Host "Сборка EPF..." -ForegroundColor Green
    python "$RepoDir\build_epf.py" "$RepoDir"

    @("vitrina_export.epf", "test_runner.epf") | ForEach-Object {
        $epf = Join-Path $RepoDir $_
        if (Test-Path $epf) {
            Write-Host "  OK: $_ ($(Get-Item $epf).Length байт)" -ForegroundColor Green
        } else {
            throw "$_ не создан!"
        }
    }
}
catch {
    Write-Host "ОШИБКА: $_" -ForegroundColor Red
    exit 1
}
