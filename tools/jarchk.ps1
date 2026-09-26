Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$jar = (Get-ChildItem (Join-Path $root 'build\libs\*.jar') -File | Where-Object { $_.Name -notlike '*sources*' } | Select-Object -First 1).FullName
Write-Output ('jar     : ' + (Split-Path $jar -Leaf))
Write-Output ('built   : ' + (Get-Item $jar).LastWriteTime)
Write-Output ('size    : ' + [math]::Round((Get-Item $jar).Length / 1KB, 1) + ' KB')
Write-Output ''
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
foreach ($p in @('data/tfc_food_port/worldgen/configured_feature/patch_blackberry_bush.json',
                 'data/tfc_food_port/neoforge/biome_modifier/berry_bushes_plains.json',
                 'META-INF/neoforge.mods.toml',
                 'data/tfc_food_port/recipe/food/cheese_curd.json')) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
  Write-Output ('===== ' + $p)
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output '  MISSING' }
}
$z.Dispose()
