Add-Type -AssemblyName System.IO.Compression.FileSystem
# derive the workspace from the TFC jar: literal non-ASCII paths get mangled by PS 5.1's GBK script encoding
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$jar = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$names = $z.Entries | ForEach-Object { $_.FullName }

Write-Output '=== vanilla biome tags ==='
$names | Where-Object { $_ -like 'data/minecraft/tags/worldgen/biome/*' } | ForEach-Object { $_ -replace '.*/', '' -replace '\.json$','' } | Sort-Object

Write-Output ''
Write-Output '=== configured features named patch_* ==='
$names | Where-Object { $_ -like 'data/minecraft/worldgen/configured_feature/patch*' } | ForEach-Object { $_ -replace '.*/', '' } | Sort-Object

Write-Output ''
Write-Output '=== feature types used by a few configured features ==='
foreach ($f in @('patch_grass_plain', 'patch_flower_plain', 'flower_plain', 'patch_taiga_grass')) {
  $e = $z.Entries | Where-Object { $_.FullName -eq "data/minecraft/worldgen/configured_feature/$f.json" } | Select-Object -First 1
  if ($e) {
    $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
    $m = [regex]::Match($t, '"type"\s*:\s*"([^"]+)"')
    Write-Output ("  $f  ->  " + $m.Groups[1].Value)
  }
}
$z.Dispose()
