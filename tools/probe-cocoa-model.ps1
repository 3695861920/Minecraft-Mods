$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem

$z = [System.IO.Compression.ZipFile]::OpenRead($merged)
function Dump([string]$p, [int]$max) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) {
    $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
    Write-Output ('===== ' + $p)
    if ($t.Length -gt $max) { Write-Output ($t.Substring(0, $max) + ' ...TRUNCATED') } else { Write-Output $t }
  } else { Write-Output ('MISSING ' + $p) }
}

Write-Output '=== vanilla cocoa blockstate ==='
Dump 'assets/minecraft/blockstates/cocoa.json' 2000
Write-Output ''
Write-Output '=== vanilla cocoa model stage2 ==='
Dump 'assets/minecraft/models/block/cocoa_stage2.json' 1200
Write-Output ''
Write-Output '=== vanilla jungle leaves model + blockstate ==='
Dump 'assets/minecraft/models/block/jungle_leaves.json' 400
Dump 'assets/minecraft/blockstates/jungle_leaves.json' 400
Write-Output ''
Write-Output '=== vanilla cocoa loot table ==='
Dump 'data/minecraft/loot_table/blocks/cocoa.json' 2000
$z.Dispose()

$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
Write-Output '=== AttachedToLeavesDecorator ==='
$e = $z2.Entries | Where-Object { $_.FullName -like '*treedecorators/AttachedToLeavesDecorator.java' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $sr.ReadToEnd(); $sr.Close()
$z2.Dispose()
