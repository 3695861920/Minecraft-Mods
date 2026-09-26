Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($merged)

function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ('MISSING ' + $p) }
}
Write-Output '=== placed features whose name looks like a plant patch ==='
$z.Entries | Where-Object { $_.FullName -like 'data/minecraft/worldgen/placed_feature/*' } | ForEach-Object { $_ -replace '.*/', '' -replace '\.json$','' } | Where-Object { $_ -match 'flower|grass|berry|melon|pumpkin|sweet' } | Sort-Object | ForEach-Object { Write-Output ('  ' + $_) }

Dump 'data/minecraft/worldgen/placed_feature/flower_plain.json'
Dump 'data/minecraft/worldgen/placed_feature/patch_sweet_berry_bush.json'
Dump 'data/minecraft/worldgen/placed_feature/melon.json'
$z.Dispose()
