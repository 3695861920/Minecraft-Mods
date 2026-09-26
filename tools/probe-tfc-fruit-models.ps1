$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)

function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ('MISSING ' + $p) }
}

Write-Output '=== TFC sapling / leaves blockstates + models (banana and red_apple) ==='
foreach ($f in @('banana', 'red_apple')) {
  Dump "assets/tfc/blockstates/plant/$f`_sapling.json"
  Dump "assets/tfc/models/block/fruit_tree/$f`_sapling.json"
  Dump "assets/tfc/models/block/fruit_tree/$f`_leaves.json"
  Dump "assets/tfc/blockstates/plant/$f`_leaves.json"
}

Write-Output '=== list TFC fruit_tree model entries (first 25) ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/models/block/fruit_tree/*' } | Select-Object -First 25 | ForEach-Object { '  ' + $_.FullName }
$z.Dispose()
