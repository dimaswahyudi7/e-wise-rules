param(
  [string]$RepoBase = "https://raw.githubusercontent.com/<user>/<repo>/main/",  # ganti sesuai lokasi
  [string]$RulesDir = "C:\\ProgramData\\EWISE\\rules",
  [string]$SysmonExe= "C:\\Tools\\Sysmon\\Sysmon64.exe"   # sesuaikan
)

$ErrorActionPreference = 'Stop'
$State = "C:\\ProgramData\\EWISE\\state.json"
$Log   = "C:\\ProgramData\\EWISE\\logs\\updater.log"
New-Item -ItemType Directory -Force -Path (Split-Path $Log) | Out-Null
New-Item -ItemType Directory -Force -Path $RulesDir | Out-Null

Function Log($m){ $ts=Get-Date -Format 's'; Add-Content $Log "$ts $m" }
Function Sha256($file){ (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash }

# 1) Ambil manifest
$manifestUrl = "$RepoBase/manifest.json".Replace('//manifest','/manifest')
$tmp = Join-Path $env:TEMP "manifest.json"
Invoke-WebRequest -UseBasicParsing -Uri $manifestUrl -OutFile $tmp
$mf = Get-Content $tmp -Raw | ConvertFrom-Json

# 2) Unduh & verifikasi semua file
foreach ($f in $mf.files) {
  $url  = "$RepoBase/$($f.path)".Replace('//','/')
  $dest = Join-Path $RulesDir (Split-Path $f.path -Leaf)
  if ($f.path -like 'scripts/*') { $dest = "C:\\ewise-agent\\scripts\" + (Split-Path $f.path -Leaf) }
  if ($f.path -like 'wazuh/*')   { $dest = "C:\\Program Files (x86)\\ossec-agent\" + ($f.path -replace '^wazuh/','') }
  if ($f.path -like 'wazuh/lists/*') { $dest = "C:\\Program Files (x86)\\ossec-agent\\lists\" + (Split-Path $f.path -Leaf) }
  if ($f.path -like 'sysmon/*')  { $dest = "C:\\ProgramData\\EWISE\" + (Split-Path $f.path -Leaf) }

  $tmpFile = Join-Path $env:TEMP ((Split-Path $f.path -Leaf) + ".tmp")
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmpFile

  $h = Sha256 $tmpFile
  if ($h -ne $f.sha256) { Log "HASH MISMATCH: $($f.path)"; Remove-Item $tmpFile -Force; continue }

  Move-Item $tmpFile $dest -Force
  Log "UPDATED: $($f.path) → $dest"
}

# 3) Terapkan sysmon config jika ada
$sysxml = "C:\\ProgramData\\EWISE\\sysmon_config.xml"
if (Test-Path $sysxml -and (Test-Path $SysmonExe)) {
  & $SysmonExe -c $sysxml | Out-Null
  Log "Sysmon config reloaded"
}

# 4) Restart ringan Wazuh Agent (agar local_rules/lists termuat)
Try { Restart-Service WazuhSvc -Force; Log "WazuhSvc restarted" } Catch { Log "Restart WazuhSvc failed: $_" }

# 5) Update state
$state = @{ rules_version = $mf.version; last_update = (Get-Date).ToString('s') }
$state | ConvertTo-Json | Out-File -Encoding utf8 $State
Log "DONE version $($mf.version)"
