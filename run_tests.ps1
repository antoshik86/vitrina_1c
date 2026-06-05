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
    $clients = @(Get-ChildItem "C:\Program Files\1cv8\*\bin\1cv8c.exe" -ErrorAction SilentlyContinue)
    $servers = @(Get-ChildItem "C:\Program Files\1cv8\*\bin\ragent.exe" -ErrorAction SilentlyContinue)
    if (-not $clients) {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\1C\1CV8\*\MainPath" -ErrorAction SilentlyContinue
        foreach ($r in $reg) {
            $p = Join-Path $r.MainPath "bin\1cv8c.exe"
            if (Test-Path $p) { $clients += Get-Item $p }
        }
    }
    if (-not $clients) {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\1C\1CV8\*\MainPath" -ErrorAction SilentlyContinue
        foreach ($r in $reg) {
            $p = Join-Path $r.MainPath "bin\1cv8c.exe"
            if (Test-Path $p) { $clients += Get-Item $p }
        }
    }
    if (-not $clients) { throw "1C not found" }

    function Get-VersionFromPath($path) {
        try { return [Version]($path | Split-Path -Parent | Split-Path -Parent | Split-Path -Leaf) } catch { return $null }
    }
    $latest = $clients | Sort-Object -Property { Get-VersionFromPath $_.FullName } -Descending | Select-Object -First 1
    $ver = Get-VersionFromPath $latest.FullName

    $serverVer = "not found"
    if ($servers) {
        $latestSrv = $servers | Sort-Object -Property { Get-VersionFromPath $_.FullName } -Descending | Select-Object -First 1
        $serverVer = Get-VersionFromPath $latestSrv.FullName
    }

    Write-Host "Client: $ver — $($latest.FullName)" -ForegroundColor Cyan
    Write-Host "Server: $serverVer" -ForegroundColor Cyan
    return $latest.FullName, $ver
}

# --------------- 2. Поиск списка ИБ ---------------
function Find-IBasesFile {
    $paths = @(
        "$env:APPDATA\1C\1CEStart\ibases.v8i",
        "$env:LOCALAPPDATA\1C\1CEStart\ibases.v8i",
        "$env:ALLUSERSPROFILE\1C\1CEStart\ibases.v8i"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Read-IBases {
    param([string]$Path)
    $bases = @()
    $current = $null
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\[(.+)\]$') {
            if ($current) { $bases += $current }
            $current = @{ Name = $Matches[1]; Connect = ""; Title = "" }
        } elseif ($line -match '^Connect=(.+)$' -and $current) {
            $current.Connect = $Matches[1]
        } elseif ($line -match '^Title=(.+)$' -and $current) {
            $current.Title = $Matches[1]
        }
    }
    if ($current) { $bases += $current }
    return $bases
}

# --------------- 3. Конфигурация подключения ---------------
function Get-Config {
    $script:OneCExe, $script:OneCVersion = Find-OneC

    if ((-not $ForceReconfig) -and (Test-Path $ConfigFile)) {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $script:IBString = $cfg.IBString
        $script:User = $cfg.User
        $script:Pass = $cfg.Pass
        Write-Host "Config loaded: $ConfigFile" -ForegroundColor DarkGray
        return
    }

    # Пробуем прочитать список баз
    $ibasesFile = Find-IBasesFile
    $ibases = @()
    $customChosen = $false
    if ($ibasesFile) {
        $ibases = Read-IBases -Path $ibasesFile
        if ($ibases.Count -gt 0) {
            Write-Host "`nСписок информационных баз:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $ibases.Count; $i++) {
                $title = if ($ibases[$i].Title) { $ibases[$i].Title } else { $ibases[$i].Name }
                Write-Host "  $($i+1). $title" -ForegroundColor Cyan
            }
            Write-Host "  0. Ввести вручную" -ForegroundColor DarkGray
            $choice = Read-Host "  Выбери номер базы"
            if ([int]$choice -gt 0 -and [int]$choice -le $ibases.Count) {
                $selected = $ibases[[int]$choice - 1]
                $script:IBString = $selected.Connect
                Write-Host "  Выбрано: $($selected.Title)" -ForegroundColor Green
            } else {
                $customChosen = $true
            }
        } else {
            $customChosen = $true
        }
    } else {
        Write-Host "Файл списка баз не найден" -ForegroundColor DarkGray
        $customChosen = $true
    }

    if ($customChosen) {
        Write-Host "`nВведи путь к ИБ вручную:" -ForegroundColor Yellow
        Write-Host '  Пример файловой: /F"C:\Base\MyDB"' -ForegroundColor DarkGray
        Write-Host '  Пример серверной: /S"Server\MyDB"' -ForegroundColor DarkGray
        $script:IBString = Read-Host "  Путь"
    }

    $script:User = Read-Host "  Пользователь"
    $spass = Read-Host "  Пароль" -AsSecureString
    $script:Pass = [System.Net.NetworkCredential]::new("", $spass).Password

    $cfg = @{ OneCExe = $OneCExe; IBString = $IBString; User = $User; Pass = $Pass }
    $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
    Write-Host "Сохранено в $ConfigFile" -ForegroundColor Green
}

# --------------- 4. Сборка EPF ---------------
function Build-EPF {
    Write-Host "`n=== Build EPF ===" -ForegroundColor Cyan

    $havePython = $false
    try {
        $v = & python --version 2>&1
        if ($v -match "Python 3") { $havePython = $true }
    } catch {}

    if ($havePython) {
        $ok = $true
        try {
            & python "$RepoDir\build_epf.py" "$RepoDir" 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) { $ok = $false }
        } catch { $ok = $false }
        if ($ok) {
            Write-Host "Python build OK" -ForegroundColor Green
            return
        }
        Write-Host "Python build failed, using pre-built EPFs" -ForegroundColor Yellow
    } else {
        Write-Host "No Python, using pre-built EPFs" -ForegroundColor DarkGray
    }

    @("vitrina_export.epf", "test_runner.epf") | ForEach-Object {
        $p = Join-Path $RepoDir $_
        if (-not (Test-Path $p)) { throw "Missing pre-built $_ — run build.ps1 on dev machine" }
        Write-Host "  OK: $_" -ForegroundColor Green
    }
}

# --------------- 5. Запуск тестов ---------------
function Run-Tests {
    Write-Host "`n=== Running 1C tests ===" -ForegroundColor Cyan
    $vitrinaEpf = Join-Path $RepoDir "vitrina_export.epf"
    $runnerEpf = Join-Path $RepoDir "test_runner.epf"
    $logFile = Join-Path $RepoDir "test_log.txt"
    Remove-Item $logFile -ErrorAction SilentlyContinue

    $argsList = @(
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

    Write-Host "Starting 1C..." -ForegroundColor DarkGray
    $proc = Start-Process -FilePath $OneCExe -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    Write-Host "1C exit code: $($proc.ExitCode)" -ForegroundColor DarkGray

    if (Test-Path $logFile) {
        $log = Get-Content $logFile -Raw
        Write-Host "`n--- 1C Log ---" -ForegroundColor DarkGray
        $log -split "`n" | Where-Object { $_.Trim() -ne "" } | ForEach-Object { Write-Host "  $_" }
        Write-Host "---------------`n" -ForegroundColor DarkGray

        if ($log -match "TEST_RESULT:\s*(.+)") {
            $result = $Matches[1].Trim()
            if ($result -like "OK*") {
                Write-Host "`nTESTS PASSED: $result" -ForegroundColor Green
                return $true
            } else {
                Write-Host "`nTESTS FAILED: $result" -ForegroundColor Red
                return $false
            }
        }
        Write-Host "TEST_RESULT not found in log" -ForegroundColor Red
        return $false
    }

    Write-Host "Log file not created: $logFile" -ForegroundColor Red
    return $false
}

# --------------- 6. Deploy zip ---------------
function New-DeployZip {
    param([string]$ZipPath = (Join-Path $RepoDir "vitrina_deploy.zip"))

    Remove-Item $ZipPath -ErrorAction SilentlyContinue
    $files = @(
        "run_tests.ps1", "build.ps1",
        "vitrina_export.epf", "test_runner.epf",
        "src\vitrina\form_module.bsl", "src\vitrina\object_module.bsl",
        "src\test_runner\form_module.bsl", "src\test_runner\object_module.bsl"
    ) | ForEach-Object { Join-Path $RepoDir $_ }

    if (Get-Command "Compress-Archive" -ErrorAction SilentlyContinue) {
        Compress-Archive -Path $files -DestinationPath $ZipPath -CompressionLevel Optimal
    } else {
        $shell = New-Object -ComObject Shell.Application
        $zip = $shell.NameSpace($ZipPath)
        $zip.CopyHere($files, 16)
        Start-Sleep -Seconds 2
    }
    Write-Host "Deploy zip: $ZipPath" -ForegroundColor Green
    return $ZipPath
}

# =============== MAIN ===============
try {
    switch ($args[0]) {
        "deploy"   { New-DeployZip; return }
        "reconfig" { $ForceReconfig = $true; Get-Config; return }
default    { Get-Config; Build-EPF; $script:testOk = Run-Tests }
    }
    if ($script:testOk) { exit 0 } else { exit 1 }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
