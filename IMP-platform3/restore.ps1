param(
    [Parameter(Mandatory=$true)]
    [string]$backupFile,
    [switch]$Force
)

$configFile = Join-Path $PSScriptRoot "backup.conf"
if (-not (Test-Path $configFile)) {
    Write-Error "Config file not found: $configFile"
    exit 1
}

$config = @{}
Get-Content $configFile -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' } | ForEach-Object {
    $keyValue = $_ -split '=', 2
    if ($keyValue.Length -eq 2) {
        $key = $keyValue[0].Trim()
        $value = $keyValue[1].Trim()
        $value = $value -replace '^"(.*)"$', '$1'
        $value = $value -replace "^'(.*)'$", '$1'
        $config[$key] = $value
    }
}

$mysqlBasedir = $config['mysqlBasedir']
$dbHost = $config['dbHost']
$dbPort = $config['dbPort']
$dbName = $config['dbName']
$dbUser = $config['dbUser']
$dbPassword = $config['dbPassword']

$mysqlBin = Join-Path $mysqlBasedir "bin"
$mysql = Join-Path $mysqlBin "mysql.exe"

if (-not (Test-Path $mysql)) {
    Write-Error "mysql.exe not found: $mysql"
    exit 1
}

if (-not (Test-Path $backupFile)) {
    Write-Error "Backup file not found: $backupFile"
    exit 1
}

Write-Host "WARNING: This operation will overwrite ALL data in database '$dbName'!" -ForegroundColor Red
if (-not $Force) {
    $confirmation = Read-Host "Continue? (y/N)"
    if ($confirmation -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Start restore database: $dbName" -ForegroundColor Green
Write-Host "Backup file: $backupFile" -ForegroundColor Cyan

try {
    if ($backupFile.EndsWith(".gz")) {
        if (Get-Command "gunzip" -ErrorAction SilentlyContinue) {
            Write-Host "Decompressing backup file..." -ForegroundColor Yellow
            $tempFile = [System.IO.Path]::GetTempFileName() + ".sql"
            & gunzip -c $backupFile | Out-File -FilePath $tempFile -Encoding Default
            
            $bytes = [System.IO.File]::ReadAllBytes($tempFile)
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo.FileName = $mysql
            $process.StartInfo.Arguments = "--binary-mode -h $dbHost -P $dbPort -u $dbUser -p$dbPassword $dbName"
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.RedirectStandardInput = $true
            $process.Start()
            $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
            $process.StandardInput.Close()
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            Remove-Item $tempFile -Force
        } else {
            Write-Error "gunzip command not found, cannot decompress .gz file"
            exit 1
        }
    } else {
        $bytes = [System.IO.File]::ReadAllBytes($backupFile)
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = $mysql
        $process.StartInfo.Arguments = "--binary-mode -h $dbHost -P $dbPort -u $dbUser -p$dbPassword $dbName"
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.RedirectStandardInput = $true
        $process.Start()
        $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
        $process.StandardInput.Close()
        $process.WaitForExit()
        $exitCode = $process.ExitCode
    }

    if ($exitCode -eq 0) {
        Write-Host "Restore completed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Error "Restore failed, mysql returned exit code: $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Error "Restore failed: $_"
    exit 1
}
