$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)

function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ('MISSING ' + $p) }
}
Dump 'assets/tfc/models/block/barrel.json'
Dump 'assets/tfc/blockstates/barrel.json'

Write-Output '=== wood/barrel textures (non-rack, non-sealed) ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/wood/barrel/*' } | ForEach-Object { $_.FullName.Substring(('assets/tfc/textures/block/wood/barrel/').Length) } | Sort-Object | ForEach-Object { Write-Output ('  ' + $_) }
$z.Dispose()

# ---- useItemOn signature, searched everywhere ----
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
Write-Output ''
Write-Output '=== where is useItemOn declared? ==='
foreach ($en in $z2.Entries) {
  if ($en.Length -eq 0 -or $en.FullName -notlike '*.java') { continue }
  $sr = New-Object System.IO.StreamReader($en.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  if ($t -match 'InteractionResult useItemOn\(') {
    foreach ($m in [regex]::Matches($t, '(?m)^\s*(?:protected |public |@Override\s*)?[^\n]*InteractionResult useItemOn\([^)]*\)?')) {
      Write-Output ('  ' + $en.FullName)
      Write-Output ('      ' + ($m.Value -replace '\s+', ' ').Trim())
    }
  }
}
$z2.Dispose()
