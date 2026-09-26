$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$base = Split-Path $jar -Parent
$out = Join-Path (Join-Path $base 'tools') 'extract'
$prefixes = @('data/tfc/loot_table/', 'data/tfc/tags/item/', 'data/tfc/tags/block/')
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$n = 0
foreach ($e in $z.Entries) {
  if ($e.Length -eq 0) { continue }
  foreach ($p in $prefixes) {
    if ($e.FullName.StartsWith($p)) {
      $dest = Join-Path $out ($e.FullName -replace '/', '\')
      $dir = Split-Path $dest -Parent
      if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
      $n++
      break
    }
  }
}
$z.Dispose()
Write-Output ("extracted: " + $n)
