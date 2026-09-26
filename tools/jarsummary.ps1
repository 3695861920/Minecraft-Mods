Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$jar = (Get-ChildItem (Join-Path $root 'build\libs\*.jar') -File | Where-Object { $_.Name -notlike '*sources*' } | Select-Object -First 1).FullName
Write-Output ('jar: ' + (Split-Path $jar -Leaf) + '   ' + [math]::Round((Get-Item $jar).Length / 1KB, 1) + ' KB')
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$names = $z.Entries | ForEach-Object { $_.FullName }

function CountOf([string]$prefix) { return ($names | Where-Object { $_ -like $prefix }).Count }

Write-Output ('  classes                : ' + (CountOf 'com/tfc_food_port/*.class'))
Write-Output ('  item model definitions : ' + (CountOf 'assets/tfc_food_port/items/*'))
Write-Output ('  item models            : ' + (CountOf 'assets/tfc_food_port/models/item/*'))
Write-Output ('  block models           : ' + (CountOf 'assets/tfc_food_port/models/block/*'))
Write-Output ('  blockstates            : ' + (CountOf 'assets/tfc_food_port/blockstates/*'))
Write-Output ('  textures               : ' + (CountOf 'assets/tfc_food_port/textures/*'))
Write-Output ('  lang files             : ' + (CountOf 'assets/tfc_food_port/lang/*'))
Write-Output ('  recipes                : ' + (CountOf 'data/tfc_food_port/recipe/*'))
Write-Output ('  loot tables            : ' + (CountOf 'data/tfc_food_port/loot_table/*'))
Write-Output ('  loot modifiers         : ' + (CountOf 'data/tfc_food_port/loot_modifiers/*'))
Write-Output ('  configured features    : ' + (CountOf 'data/tfc_food_port/worldgen/configured_feature/*'))
Write-Output ('  placed features        : ' + (CountOf 'data/tfc_food_port/worldgen/placed_feature/*'))
Write-Output ('  biome modifier         : ' + (CountOf 'data/tfc_food_port/neoforge/biome_modifier/*'))
Write-Output ('  own tags               : ' + (CountOf 'data/tfc_food_port/tags/*'))
Write-Output ('  common (c:) tags       : ' + (CountOf 'data/c/tags/*'))
Write-Output ('  mods.toml              : ' + (CountOf 'META-INF/neoforge.mods.toml'))
$z.Dispose()
