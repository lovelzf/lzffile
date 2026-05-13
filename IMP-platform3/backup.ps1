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
$backupLocation = $config['backupLocation']
$enableCompression = $config['enableCompression']
$keepDays = [int]$config['keepDays']

if (-not $mysqlBasedir) {
    Write-Error "Failed to read config, mysqlBasedir is empty. Check backup.conf format."
    exit 1
}

$mysqlBin = Join-Path $mysqlBasedir "bin"
$mysqldump = Join-Path $mysqlBin "mysqldump.exe"

if (-not (Test-Path $mysqldump)) {
    Write-Error "mysqldump.exe not found: $mysqldump"
    exit 1
}

$backupDir = $backupLocation
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$databaseName = $dbName
$backupFile = Join-Path $backupDir "${databaseName}_backup_${timestamp}.sql"
$compressFile = "$backupFile.gz"

Write-Host "Start backup database: $databaseName" -ForegroundColor Green
Write-Host "Backup file: $backupFile" -ForegroundColor Cyan

try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $mysqldump
    $psi.Arguments = "-h $dbHost -P $dbPort -u $dbUser -p`"$dbPassword`" $databaseName --result-file=`"$backupFile`""
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null
    $process.WaitForExit()
    
    if ($enableCompression -eq "true") {
        if (Get-Command "gzip" -ErrorAction SilentlyContinue) {
            gzip $backupFile
            Write-Host "Backup completed and compressed: $compressFile" -ForegroundColor Green
        } else {
            Write-Host "Backup completed: $backupFile (gzip not found, no compression)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Backup completed: $backupFile" -ForegroundColor Green
    }

    if ($keepDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$keepDays)
        $oldFiles = Get-ChildItem $backupDir -Filter "${databaseName}_backup_*.sql*" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
        if ($oldFiles.Count -gt 0) {
            Write-Host "Deleting $($oldFiles.Count) old backup files older than $keepDays days..." -ForegroundColor Yellow
            $oldFiles | Remove-Item -Force
            Write-Host "Cleanup completed" -ForegroundColor Green
        }
    }

    $fileSize = if (Test-Path $compressFile) { (Get-Item $compressFile).Length / 1MB } else { (Get-Item $backupFile).Length / 1MB }
    Write-Host "Backup size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    exit 0
} catch {
    Write-Error "Backup failed: $_"
    exit 1
}
