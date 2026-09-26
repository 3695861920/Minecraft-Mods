Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$jar = (Get-ChildItem (Join-Path $root 'FarmersDelight*.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)

Write-Output '=== top-level asset folders of a known-good 26.1.2 mod ==='
$z.Entries | ForEach-Object { ($_.FullName -split '/')[0..2] -join '/' } | Sort-Object -Unique | Where-Object { $_ -like 'assets/farmersdelight/*' }

Write-Output ''
Write-Output '=== does assets/farmersdelight/items/ exist? ==='
$items = $z.Entries | Where-Object { $_.FullName -like 'assets/farmersdelight/items/*.json' }
Write-Output ('  count: ' + $items.Count)
$items | Select-Object -First 6 | ForEach-Object { Write-Output ('   ' + $_.FullName) }

Write-Output ''
Write-Output '=== sample item definition vs its model ==='
function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ('MISSING ' + $p) }
}
Dump 'assets/farmersdelight/items/cabbage.json'
Dump 'assets/farmersdelight/models/item/cabbage.json'
Dump 'assets/farmersdelight/items/cooking_pot.json'
Dump 'assets/farmersdelight/models/item/cooking_pot.json'
$z.Dispose()
