# vitrina_1c run_tests.ps1 — сборка + тестирование в 1С
# Запрашивает параметры подключения при первом запуске, сохраняет в test_config.json
param(
    [string]$RepoDir = $PSScriptRoot,
    [string]$OneCExe = "",
    [string]$IBString = "",
    [string]$User = "",
    [string]$Pass = ""
)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $RepoDir "test_config.json"

# ----- 1. Поиск 1С -----
function Find-OneC {
    $versions = @(Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8c.exe" -ErrorAction SilentlyContinue)
    if ($versions.Count -eq 0) {
        throw "1С:Предприятие (тонкий клиент) не найден"
    }
    # pick latest version
    return $versions[-1].FullName
}

# ----- 2. Загрузка/запрос конфигурации -----
function Get-Config {
    if ($OneCExe) { return }  # all params provided via CLI

    if (Test-Path $ConfigFile) {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $script:OneCExe = $cfg.OneCExe
        $script:IBString = $cfg.IBString
        $script:User = $cfg.User
        $script:Pass = $cfg.Pass
        Write-Host "Конфигурация загружена из $ConfigFile" -ForegroundColor DarkGray
        return
    }

    $script:OneCExe = Find-OneC
    Write-Host "Найден 1С: $OneCExe" -ForegroundColor Cyan

    Write-Host "`nПараметры подключения к информационной базе:" -ForegroundColor Yellow
    $script:IBString = Read-Host "  Путь к файловой ИБ (/F) или строка подключения (/S)"
    $script:User = Read-Host "  Пользователь"
    $script:Pass = Read-Host "  Пароль" -AsSecureString
    $plainPass = [System.Net.NetworkCredential]::new("", $Pass).Password
    $script:Pass = $plainPass

    $cfg = @{ OneCExe = $OneCExe; IBString = $IBString; User = $User; Pass = $Pass }
    $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
    Write-Host "Сохранено в $ConfigFile" -ForegroundColor DarkGray
}

# ----- 3. Сборка -----
function Build-EPF {
    Write-Host "`n=== Сборка vitrina_export.epf ===" -ForegroundColor Cyan
    & "python" "$RepoDir\build_epf.py" "$RepoDir"
    if ($LASTEXITCODE -ne 0) { throw "Сборка EPF не удалась" }
}

function Build-TestRunner {
    Write-Host "Сборка test_runner.epf..." -ForegroundColor Cyan
    $src = Join-Path $RepoDir "tests\test_runner"
    $out = Join-Path $RepoDir "test_runner.epf"
    & "python" "$RepoDir\build_epf.py" "--src" "$src" "--out" "$out"
    if ($LASTEXITCODE -ne 0) { throw "Сборка test_runner не удалась" }
}

# ----- 4. Запуск тестов в 1С -----
function Run-Tests {
    Write-Host "`n=== Запуск тестов в 1С ===" -ForegroundColor Cyan
    $vitrinaEpf = Join-Path $RepoDir "vitrina_export.epf"
    $runnerEpf = Join-Path $RepoDir "test_runner.epf"
    $logFile = Join-Path $RepoDir "test_log.txt"

    $argsList = @(
        "ENTERPRISE"
        $IBString
        "/N`"$User`""
        "/P`"$Pass`""
        "/Execute`"$runnerEpf`""
        "/C`"$vitrinaEpf`""
        "/Out`"$logFile`""
        "/Close-After"
        "/DisableStartupMessages"
    )

    Write-Host "Запуск: $OneCExe $IBString /Execute`"$runnerEpf`" /C`"...`"" -ForegroundColor DarkGray
    $proc = Start-Process -FilePath $OneCExe -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    Write-Host "1С завершилась с кодом $($proc.ExitCode)" -ForegroundColor DarkGray

    # Парсим лог
    if (Test-Path $logFile) {
        $log = Get-Content $logFile -Raw
        Write-Host "`n--- Лог 1С ---" -ForegroundColor DarkGray
        Write-Host $log.Substring(0, [Math]::Min($log.Length, 2000))
        Write-Host "--------------`n" -ForegroundColor DarkGray

        if ($log -match "TEST_RESULT: (.+)") {
            $result = $Matches[1]
            if ($result -like "OK*") {
                Write-Host "ТЕСТЫ ПРОЙДЕНЫ: $result" -ForegroundColor Green
                return $true
            } else {
                Write-Host "ТЕСТЫ НЕ ПРОЙДЕНЫ: $result" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "TEST_RESULT не найден в логе" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "Лог-файл не создан: $logFile" -ForegroundColor Red
        return $false
    }
}

# ----- MAIN -----
try {
    Get-Config
    Build-EPF
    Build-TestRunner
    $ok = Run-Tests
    exit (0 if $ok else 1)
}
catch {
    Write-Host "ОШИБКА: $_" -ForegroundColor Red
    exit 1
}
