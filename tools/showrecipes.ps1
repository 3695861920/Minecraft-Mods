$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$r = Join-Path $root 'src\main\resources\data\tfc_food_port\recipe'
foreach ($p in @('food/wheat_dough_from_crafting.json', 'food/wheat_dough_from_cooking.json', 'food/wheat_grain.json',
                 'food/wheat_bread_from_smelting.json', 'food/vegetables_soup.json', 'food/cheese_curd.json',
                 'food/jam/blackberry.json', 'food/wheat_bread_jam_sandwich.json', 'food/melon_slice.json')) {
  Write-Output ('===== ' + $p)
  Write-Output ([System.IO.File]::ReadAllText((Join-Path $r ($p -replace '/', '\')), [System.Text.Encoding]::UTF8))
}
Write-Output '===== tags/item/jams.json'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $root 'src\main\resources\data\tfc_food_port\tags\item\jams.json'), [System.Text.Encoding]::UTF8))
