$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

Write-Output '=== available foliage placers ==='
$z.Entries | Where-Object { $_.FullName -like '*levelgen/feature/foliageplacers/*' } | ForEach-Object { '  ' + $_.FullName.Split('/')[-1] }

Write-Output ''
Write-Output '=== BlobFoliagePlacer.createFoliage + foliageHeight ==='
$e = $z.Entries | Where-Object { $_.FullName -like '*foliageplacers/BlobFoliagePlacer.java' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'createFoliage|foliageHeight|radius|CODEC|RecordCodecBuilder') {
    for ($j = [Math]::Max(0, $i - 1); $j -le [Math]::Min($lines.Count - 1, $i + 6); $j++) { Write-Output ('  ' + ($j + 1).ToString().PadLeft(4) + ': ' + $lines[$j]) }
    Write-Output '  ---'
    $i += 6
  }
}

Write-Output ''
Write-Output '=== vanilla acacia configured feature (flat canopy, palm-ish) ==='
$z.Dispose()
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$z2 = [System.IO.Compression.ZipFile]::OpenRead($merged)
$e2 = $z2.Entries | Where-Object { $_.FullName -eq 'data/minecraft/worldgen/configured_feature/acacia.json' } | Select-Object -First 1
$sr2 = New-Object System.IO.StreamReader($e2.Open()); Write-Output $sr2.ReadToEnd(); $sr2.Close()

Write-Output ''
Write-Output '=== tree decorator types available ==='
$z2.Entries | Where-Object { $_.FullName -like '*levelgen/treedecorators/*' } | ForEach-Object { '  ' + $_.FullName.Split('/')[-1] }
$z2.Dispose()
