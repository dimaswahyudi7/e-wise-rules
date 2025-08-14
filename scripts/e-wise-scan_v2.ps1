param(
  [string]$InJsonl = "C:\\ProgramData\\EWISE\\logs\\custom.jsonl",
  [string]$OutJsonl= "C:\\ProgramData\\EWISE\\logs\\custom.jsonl"
)
if (-not (Test-Path $InJsonl)) { exit 0 }

$since = (Get-Date).AddHours(-1)
$lines = Get-Content $InJsonl | Select-Object -Last 1000
$events = foreach ($ln in $lines) { try { $ln | ConvertFrom-Json } catch { } }
$recent = $events | Where-Object { $_.ts -and [datetime]$_.ts -ge $since -and $_.type -like 'piracy.*' }

if ($recent.Count -ge 2) {
  $obj = [ordered]@{
    ts        = (Get-Date).ToString('s')
    type      = 'piracy.correlation'
    indicator = "count=$($recent.Count) in 1h"
    src       = 'correlator'
    severity  = 'high'
    extra     = @{ sample = $recent | Select-Object -First 3 }
  }
  ($obj | ConvertTo-Json -Compress) + "`n" | Out-File -Append -Encoding utf8 $OutJsonl
}
