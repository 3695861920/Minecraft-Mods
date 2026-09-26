$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$assets = Join-Path $root 'src\main\resources\assets\tfc_food_port'
$data = Join-Path $root 'src\main\resources\data\tfc_food_port'

Write-Output '=== 1. saplings hidden (no item definition / no item model) ==='
$sapDefs = Get-ChildItem (Join-Path $assets 'items') -Recurse -File -Filter '*_sapling.json' -ErrorAction SilentlyContinue
$sapModels = Get-ChildItem (Join-Path $assets 'models\item') -Recurse -File -Filter '*_sapling.json' -ErrorAction SilentlyContinue
Write-Output ("  sapling item definitions: " + @($sapDefs).Count + "   sapling item models: " + @($sapModels).Count + "   (both must be 0)")

Write-Output ''
Write-Output '=== 2. leaves loot must never drop a sapling ==='
$bad = 0
Get-ChildItem (Join-Path $data 'loot_table\blocks\plant') -File -Filter '*_leaves.json' | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  if ($t -match '_sapling') { Write-Output ('  SAUPLING IN ' + $_.Name); $bad++ }
}
Write-Output ("  leaves tables dropping a sapling: $bad")

Write-Output ''
Write-Output '=== 3. leaves drop rate (one guaranteed + 20% extra) ==='
$t = [System.IO.File]::ReadAllText((Join-Path $data 'loot_table\blocks\plant\red_apple_leaves.json'), [System.Text.Encoding]::UTF8)
Write-Output ('  contains 0.2 chance: ' + ($t -match '"chance"\s*:\s*0\.2'))
Write-Output ('  pool count: ' + ([regex]::Matches($t, '"rolls"')).Count)

Write-Output ''
Write-Output '=== 4. banana bunch (cocoa-style) ==='
foreach ($p in @("$assets\blockstates\plant\banana_bunch.json", "$assets\models\block\plant\banana_bunch.json", "$data\loot_table\blocks\plant\banana_bunch.json")) {
  Write-Output ('  ' + ($(if (Test-Path $p) { 'OK   ' } else { 'MISS ' })) + $p.Substring($assets.Length + 1))
}

Write-Output ''
Write-Output '=== 5. banana leaves use vanilla jungle leaves ==='
$lm = Join-Path $assets 'models\block\plant\banana_leaves.json'
Write-Output ('  jungle_leaves referenced: ' + ([System.IO.File]::ReadAllText($lm, [System.Text.Encoding]::UTF8) -match 'minecraft:block/jungle_leaves'))
Write-Output ('  frond elements: ' + ([regex]::Matches([System.IO.File]::ReadAllText($lm, [System.Text.Encoding]::UTF8), '"from"')).Count)

Write-Output ''
Write-Output '=== 6. banana tree shape (tall bare trunk, small crown) ==='
$cf = [System.IO.File]::ReadAllText((Join-Path $data 'worldgen\configured_feature\banana_tree.json'), [System.Text.Encoding]::UTF8)
$m = [regex]::Match($cf, '"base_height"\s*:\s*(\d+)'); Write-Output ('  trunk base_height: ' + $(if ($m.Success) { $m.Groups[1].Value } else { '?' }))
$m2 = [regex]::Match($cf, '"radius"\s*:\s*(\d+)'); Write-Output ('  crown radius: ' + $(if ($m2.Success) { $m2.Groups[1].Value } else { '?' }))
$m3 = [regex]::Match($cf, '"Name"\s*:\s*"(minecraft:oak_log)"'); Write-Output ('  trunk block: ' + $(if ($m3.Success) { $m3.Groups[1].Value } else { '?' }))

Write-Output ''
Write-Output '=== 7. lang keys present ==='
$jz = [System.IO.File]::ReadAllText((Join-Path $assets 'lang\zh_cn.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
foreach ($k in @('block.tfc_food_port.plant.banana_sapling', 'block.tfc_food_port.plant.banana_leaves',
                 'block.tfc_food_port.plant.banana_bunch', 'block.tfc_food_port.plant.red_apple_leaves')) {
  $p = $jz.PSObject.Properties | Where-Object { $_.Name -eq $k } | Select-Object -First 1
  Write-Output ('  ' + $k + ' = ' + $(if ($p) { $p.Value } else { 'MISSING' }))
}
Write-Output ('  total lang keys: ' + $jz.PSObject.Properties.Count)
