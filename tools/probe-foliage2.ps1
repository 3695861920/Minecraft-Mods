$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem

$z = [System.IO.Compression.ZipFile]::OpenRead($merged)
$e = $z.Entries | Where-Object { $_.FullName -eq 'data/minecraft/worldgen/configured_feature/acacia.json' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
$i = $t.IndexOf('foliage_placer'); $j = $t.IndexOf('foliage_provider')
Write-Output '=== acacia foliage_placer block ==='
if ($i -ge 0 -and $j -gt $i) { Write-Output $t.Substring($i - 4, $j - $i + 4) } else { Write-Output 'not found' }

Write-Output ''
Write-Output '=== all tree decorator types ==='
$z.Entries | Where-Object { $_.FullName -like '*levelgen/treedecorators/*' } | ForEach-Object { '  ' + $_.FullName.Split('/')[-1] }
$z.Dispose()

$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
Write-Output ''
Write-Output '=== FoliagePlacer.placeLeavesRow (how the row is filled) ==='
$e2 = $z2.Entries | Where-Object { $_.FullName -like '*foliageplacers/FoliagePlacer.java' } | Select-Object -First 1
$sr2 = New-Object System.IO.StreamReader($e2.Open()); $lines = $sr2.ReadToEnd() -split "`r?`n"; $sr2.Close()
for ($k = 0; $k -lt $lines.Count; $k++) {
  if ($lines[$k] -match 'placeLeavesRow|shouldSkipLocation|placeLeavesRowWithHangingLeavesBelow') {
    for ($m = $k; $m -le [Math]::Min($lines.Count - 1, $k + 22); $m++) { Write-Output ('  ' + ($m + 1).ToString().PadLeft(4) + ': ' + $lines[$m]) }
    Write-Output '  ---'
    $k += 22
  }
}
$z2.Dispose()
