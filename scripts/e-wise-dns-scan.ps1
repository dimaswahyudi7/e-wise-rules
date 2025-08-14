param(
  [string]$DomainsList = "C:\\ProgramData\\EWISE\\rules\\piracy_domains.txt",
  [string]$OutJsonl    = "C:\\ProgramData\\EWISE\\logs\\custom.jsonl"
)

# Pastikan file list tersedia (akan diisi oleh updater)
if (-not (Test-Path $DomainsList)) { Write-Host "[dns-scan] List not found: $DomainsList"; exit 0 }
$domains = Get-Content $DomainsList | Where-Object { $_ -and (-not $_.StartsWith('#')) } | ForEach-Object { $_.Trim() }

# Ambil query DNS aktif via Sysmon (Event ID 22) menggunakan Get-WinEvent (24 jam terakhir sebagai contoh)
$since = (Get-Date).AddHours(-24)
$filter = @{LogName='Microsoft-Windows-Sysmon/Operational'; StartTime=$since; Id=22}
$events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue

foreach ($evt in $events) {
  $xml = [xml]$evt.ToXml()
  $qname = ($xml.Event.EventData.Data | Where-Object {$_.Name -eq 'QueryName'}).'#text'
  if (-not $qname) { continue }
  foreach ($d in $domains) {
    if ($qname -like "*$d*") {
      $obj = [ordered]@{
        ts        = (Get-Date).ToString('s')
        type      = 'piracy.domain'
        indicator = $qname
        src       = 'dns-scan'
        severity  = 'medium'
        extra     = @{ list = $d }
      }
      ($obj | ConvertTo-Json -Compress) + "`n" | Out-File -Append -Encoding utf8 $OutJsonl
      break
    }
  }
}
