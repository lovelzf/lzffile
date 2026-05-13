$configFile = Join-Path $PSScriptRoot "backup.conf"
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

Write-Host "Testing connection to ${dbHost}:${dbPort}..."
& $mysql -h $dbHost -P $dbPort -u $dbUser -p"$dbPassword" -e "SELECT VERSION();" 2>&1
