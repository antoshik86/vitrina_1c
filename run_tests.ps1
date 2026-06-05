# vitrina_1c run_tests.ps1 — сборка + тестирование в 1С
# Pure PowerShell, работает на Windows Server 2025 без Python
param(
    [string]$RepoDir = $PSScriptRoot,
    [switch]$ForceReconfig
)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $RepoDir "test_config.json"

# --------------- 1. Поиск платформы 1С ---------------
function Find-OneC {
    # Сканируем каталог установки
    $versions = @(Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8c.exe" -ErrorAction SilentlyContinue)
    
    # Проверяем реестр (64-bit)
    if (-not $versions) {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\1C\1CV8\*\MainPath" -ErrorAction SilentlyContinue
        foreach ($r in $reg) {
            $p = Join-Path $r.MainPath "bin\1cv8c.exe"
            if (Test-Path $p) { $versions += Get-Item $p }
        }
    }
    
    # Проверяем реестр (32-bit на 64-bit)
    if (-not $versions) {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\1C\1CV8\*\MainPath" -ErrorAction SilentlyContinue
        foreach ($r in $reg) {
            $p = Join-Path $r.MainPath "bin\1cv8c.exe"
            if (Test-Path $p) { $versions += Get-Item $p }
        }
    }
    
    if (-not $versions) { throw "1С:Предприятие не найдено" }
    
    # Берём последнюю версию (сортировка по имени каталога)
    $latest = $versions | Sort-Object -Property @{Expression={[Version]($_ | Split-Path -Parent | Split-Path -Parent | Split-Path -Leaf)}} -Descending | Select-Object -First 1
    $ver = $latest | Split-Path -Parent | Split-Path -Parent | Split-Path -Leaf
    Write-Host "Найдена платформа 1С: $ver — $($latest.FullName)" -ForegroundColor Cyan
    return $latest.FullName, $ver
}

# --------------- 2. Конфигурация подключения ---------------
function Get-Config {
    $script:OneCExe, $script:OneCVersion = Find-OneC

    if ((-not $ForceReconfig) -and (Test-Path $ConfigFile)) {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $script:IBString = $cfg.IBString
        $script:User = $cfg.User
        $script:Pass = $cfg.Pass
        Write-Host "Конфигурация загружена: $ConfigFile" -ForegroundColor DarkGray
        return
    }

    Write-Host "`nПараметры подключения к информационной базе:" -ForegroundColor Yellow
    Write-Host "  Пример файловой: /F""C:\Base\MyDB""" -ForegroundColor DarkGray
    Write-Host "  Пример серверной: /S""Server\MyDB""" -ForegroundColor DarkGray
    $script:IBString = Read-Host "  Путь к ИБ"
    $script:User = Read-Host "  Пользователь"
    $spass = Read-Host "  Пароль" -AsSecureString
    $script:Pass = [System.Net.NetworkCredential]::new("", $spass).Password

    $cfg = @{ OneCExe = $OneCExe; IBString = $IBString; User = $User; Pass = $Pass }
    $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
    Write-Host "Сохранено в $ConfigFile" -ForegroundColor Green
}

# --------------- 3. Сборка EPF (опционально, если есть Python) ---------------
function Build-EPF {
    Write-Host "`n=== Сборка EPF ===" -ForegroundColor Cyan

    # Проверяем, есть ли Python
    $havePython = $false
    try {
        $v = & python --version 2>&1
        if ($v -match "Python 3") { $havePython = $true }
    } catch {}

    if ($havePython) {
        # Пробуем собрать через Python + v8unpack
        $ok = $true
        try {
            & python "$RepoDir\build_epf.py" "$RepoDir" 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) { $ok = $false }
        } catch { $ok = $false }

        if ($ok) {
            Write-Host "Сборка через Python выполнена" -ForegroundColor Green
            return
        }
        Write-Host "Сборка через Python не удалась, использую предсобранные EPF" -ForegroundColor Yellow
    } else {
        Write-Host "Python не найден, использую предсобранные EPF" -ForegroundColor DarkGray
    }

    # Проверяем предсобранные EPF
    @("vitrina_export.epf", "test_runner.epf") | ForEach-Object {
        $p = Join-Path $RepoDir $_
        if (-not (Test-Path $p)) { throw "Не найден предсобранный $_ — запусти build.ps1 на машине разработки" }
        Write-Host "  OK: $_" -ForegroundColor Green
    }
}

# --------------- 4. Запуск тестов в 1С ---------------
function Run-Tests {
    Write-Host "`n=== Запуск тестов в 1С ===" -ForegroundColor Cyan
    $vitrinaEpf = Join-Path $RepoDir "vitrina_export.epf"
    $runnerEpf = Join-Path $RepoDir "test_runner.epf"
    $logFile = Join-Path $RepoDir "test_log.txt"
    Remove-Item $logFile -ErrorAction SilentlyContinue

    $args = @(
        "ENTERPRISE"
        "$IBString"
        "/N`"$User`""
        "/P`"$Pass`""
        "/Execute`"$runnerEpf`""
        "/C`"$vitrinaEpf`""
        "/Out`"$logFile`""
        "/DisableStartupMessages"
        "/DisableUnsupportedPresentationWarning"
    )

    Write-Host "Запуск 1С..." -ForegroundColor DarkGray
    $proc = Start-Process -FilePath $OneCExe -ArgumentList $args -NoNewWindow -Wait -PassThru
    Write-Host "Процесс 1С завершён (код: $($proc.ExitCode))" -ForegroundColor DarkGray

    # Парсим результат
    if (Test-Path $logFile) {
        $log = Get-Content $logFile -Raw
        Write-Host "`n--- Лог 1С ---" -ForegroundColor DarkGray
        $logLines = $log -split "`n" | Where-Object { $_.Trim() -ne "" }
        $logLines | ForEach-Object { Write-Host "  $_" }
        Write-Host "---------------`n" -ForegroundColor DarkGray

        if ($log -match "TEST_RESULT:\s*(.+)") {
            $result = $Matches[1].Trim()
            if ($result -like "OK*") {
                Write-Host "`nТЕСТЫ ПРОЙДЕНЫ: $result" -ForegroundColor Green
                return $true
            } else {
                Write-Host "`nТЕСТЫ НЕ ПРОЙДЕНЫ: $result" -ForegroundColor Red
                return $false
            }
        }
        Write-Host "TEST_RESULT не найден в логе" -ForegroundColor Red
        return $false
    }

    Write-Host "Лог-файл не создан: $logFile" -ForegroundColor Red
    return $false
}

# --------------- 5. Упаковка для деплоя ---------------
function New-DeployZip {
    param([string]$ZipPath = (Join-Path $RepoDir "vitrina_deploy.zip"))
    
    Remove-Item $ZipPath -ErrorAction SilentlyContinue
    $files = @(
        "run_tests.ps1", "build.ps1",
        "vitrina_export.epf", "test_runner.epf",
        "src\vitrina\form_module.bsl", "src\vitrina\object_module.bsl",
        "src\test_runner\form_module.bsl", "src\test_runner\object_module.bsl"
    ) | ForEach-Object { Join-Path $RepoDir $_ }

    # Определяем, доступен ли Compress-Archive (PowerShell 5+)
    if (Get-Command "Compress-Archive" -ErrorAction SilentlyContinue) {
        Compress-Archive -Path $files -DestinationPath $ZipPath -CompressionLevel Optimal
    } else {
        # Fallback: используем Shell.Application
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($ZipPath)
        $zip.CopyHere($files, 16)
        Start-Sleep -Seconds 2
    }
    Write-Host "Архив создан: $ZipPath" -ForegroundColor Green
    return $ZipPath
}

# =============== MAIN ===============
try {
    switch ($args[0]) {
        "deploy"   { New-DeployZip; return }
        "reconfig" { $ForceReconfig = $true; Get-Config; return }
        default    { Get-Config; Build-EPF; $ok = Run-Tests }
    }
    exit (0 if $ok else 1)
}
catch {
    Write-Host "`nОШИБКА: $_" -ForegroundColor Red
    exit 1
}
