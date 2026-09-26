$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($merged)

function Dump([string]$p) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ('===== ' + $p); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ('MISSING ' + $p) }
}

Write-Output '=== an oak-like tree configured feature (oak.json) ==='
Dump 'data/minecraft/worldgen/configured_feature/oak.json'
Write-Output '=== its placed feature ==='
Dump 'data/minecraft/worldgen/placed_feature/oak_checked.json'

Write-Output '=== vanilla oak leaves blockstate ==='
Dump 'assets/minecraft/blockstates/oak_leaves.json'
$z.Dispose()

# leaves subclass candidates
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
Write-Output '=== LeavesBlock subclasses in vanilla ==='
$z2.Entries | Where-Object { $_.FullName -like '*leaves*' -or $_.FullName -like '*Leaves*' } | ForEach-Object { Write-Output ('  ' + $_.FullName) }
Write-Output '=== abstract members of LeavesBlock ==='
$e = $z2.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/level/block/LeavesBlock.java' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
$lines | Select-String -Pattern 'abstract|protected MapCodec|codec\(\)|public static final MapCodec' | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(4) + ': ' + $_.Line.Trim()) }
$z2.Dispose()
