param(
  [string]$BackupRoot = 'E:\Project 2026\QuickParking-Backup'
)

$ErrorActionPreference = 'Stop'

function Get-PsqlPath {
  $command = Get-Command psql -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $installed = Get-ChildItem 'C:\Program Files\PostgreSQL' -Recurse `
    -Filter 'psql.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
  if ($installed) {
    return $installed
  }

  throw 'PostgreSQL command-line tools are not installed. Install PostgreSQL, then run this script again.'
}

function ConvertFrom-SecureText([Security.SecureString]$Value) {
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  }
}

$dateFolder = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$outputFolder = Join-Path $BackupRoot "CSV\\$dateFolder"
New-Item -ItemType Directory -Force -Path $outputFolder | Out-Null

$psql = Get-PsqlPath
$secureUrl = Read-Host 'Paste the Supabase database connection string' -AsSecureString
$databaseUrl = ConvertFrom-SecureText $secureUrl

try {
  $tables = @(
    'users',
    'admins',
    'parking_locations',
    'parking_slots',
    'bookings',
    'payments',
    'notifications',
    'complaints'
  )

  foreach ($table in $tables) {
    $file = (Join-Path $outputFolder "$table.csv").Replace('\\', '/')
    Write-Host "Exporting $table..."
    & $psql "--dbname=$databaseUrl" '--set=ON_ERROR_STOP=on' `
      -c "\\copy public.$table TO '$file' WITH CSV HEADER"
    if ($LASTEXITCODE -ne 0) {
      throw "Could not export public.$table."
    }
  }

  $manifest = Join-Path $outputFolder 'backup-info.txt'
  @(
    'QuickParking CSV backup',
    "Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Tables: $($tables -join ', ')"
  ) | Set-Content -LiteralPath $manifest -Encoding utf8

  Write-Host "Backup completed: $outputFolder" -ForegroundColor Green
} finally {
  $databaseUrl = $null
}
