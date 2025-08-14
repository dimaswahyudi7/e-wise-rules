param(
  [string]$FilenameList = "C:\\ProgramData\\EWISE\\rules\\piracy_urls.txt",
  [string]$HashList     = "C:\\ProgramData\\EWISE\\rules\\piracy_hashes.txt",
  [string]$ScanPath     = "C:\\Users\\*\\Downloads",
  [string]$OutJsonl     = "C:\\ProgramData\\EWISE\\logs\\custom.jsonl"
)

# Muat list
$names = @( ); if (Test-Path $FilenameList) { $names = Get-Content $FilenameList | Where-Object { $_ -and (-not $_.StartsWith('#')) } }
$hashes= @( ); if (Test-Path $HashList)     { $hashes= Get-Content $HashList | Where-Object { $_ -and (-not $_.StartsWith('#')) } }

# Enumerasi file
$files = Get-ChildItem -Path $ScanPath -Recurse -File -ErrorAction SilentlyContinue
foreach ($f in $files) {
  $hitName = $false
  foreach ($n in $names) { if ($f.Name -like "*$n*") { $hitName = $true; break } }

  $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash
  $hitHash = $hashes -contains $sha256

  if ($hitName -or $hitHash) {
    $obj = [ordered]@{
      ts        = (Get-Date).ToString('s')
      type      = 'piracy.file'
      indicator = $f.FullName
      src       = 'file-scan'
      severity  = if ($hitHash) { 'high' } else { 'medium' }
      extra     = @{ sha256 = $sha256; name_match = $hitName; hash_match = $hitHash }
    }
    ($obj | ConvertTo-Json -Compress) + "`n" | Out-File -Append -Encoding utf8 $OutJsonl
  }
}
