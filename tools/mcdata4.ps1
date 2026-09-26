Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($merged)

function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ('MISSING ' + $p) }
}

$types = @{}
foreach ($en in $z.Entries) {
  if ($en.Length -eq 0 -or $en.FullName -notlike 'data/minecraft/worldgen/placed_feature/*.json') { continue }
  $sr = New-Object System.IO.StreamReader($en.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  foreach ($m in [regex]::Matches($t, '"type"\s*:\s*"([^"]+)"')) {
    if ($m.Groups[1].Value -like 'minecraft:*') { $types[$m.Groups[1].Value] = 1 }
  }
}
Write-Output '=== all placement modifier / provider types seen in vanilla placed features ==='
$types.Keys | Sort-Object | ForEach-Object { Write-Output ('  ' + $_) }

Dump 'data/minecraft/worldgen/placed_feature/patch_berry_bush.json'
Dump 'data/minecraft/worldgen/configured_feature/berry_bush.json'
Dump 'data/minecraft/worldgen/placed_feature/patch_grass_plain.json'
$z.Dispose()
