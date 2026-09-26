$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$res = Join-Path $root 'src\main\resources'
$assets = Join-Path $res 'assets\tfc_food_port'
$data = Join-Path $res 'data\tfc_food_port'

Add-Type -AssemblyName System.Web.Extensions
$parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$bad = 0; $n = 0
Get-ChildItem $res -Recurse -File -Filter *.json | ForEach-Object {
  $n++; $p = $_.FullName
  try { [void]$parser.DeserializeObject([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)) }
  catch { $bad++; Write-Output ('INVALID: ' + $p.Replace($res + '\', '') + ' :: ' + $_.Exception.Message) }
}
Write-Output ("json total: $n   invalid: $bad")
Write-Output ("item models : " + (Get-ChildItem (Join-Path $assets 'models\item') -Recurse -File).Count)
Write-Output ("block models: " + (Get-ChildItem (Join-Path $assets 'models\block') -Recurse -File).Count)
Write-Output ("blockstates : " + (Get-ChildItem (Join-Path $assets 'blockstates') -Recurse -File).Count)
Write-Output ("textures    : " + (Get-ChildItem (Join-Path $assets 'textures') -Recurse -File).Count)
Write-Output ("loot tables : " + (Get-ChildItem (Join-Path $data 'loot_table') -Recurse -File).Count)
Write-Output ("configured  : " + (Get-ChildItem (Join-Path $data 'worldgen\configured_feature') -Recurse -File).Count)
Write-Output ("placed      : " + (Get-ChildItem (Join-Path $data 'worldgen\placed_feature') -Recurse -File).Count)
Write-Output ("biome mods  : " + (Get-ChildItem (Join-Path $data 'neoforge\biome_modifier') -Recurse -File).Count)

$j = [System.IO.File]::ReadAllText((Join-Path $assets 'lang\zh_cn.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
Write-Output '--- bush translations ---'
foreach ($w in @('block.tfc_food_port.plant.blackberry_bush', 'block.tfc_food_port.plant.banana_bush',
                 'block.tfc_food_port.plant.strawberry_bush', 'block.tfc_food_port.plant.red_apple_bush')) {
  $p = $j.PSObject.Properties | Where-Object { $_.Name -eq $w }
  if ($p) { Write-Output ('  ' + $w + ' = ' + $p.Value) } else { Write-Output ('  MISSING ' + $w) }
}

Write-Output '--- biome modifier (forest) ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $data 'neoforge\biome_modifier\berry_bushes_forest.json')))
Write-Output '--- configured feature (blackberry) ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $data 'worldgen\configured_feature\patch_blackberry_bush.json')))
Write-Output '--- bush loot (blackberry) ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $data 'loot_table\blocks\plant\blackberry_bush.json')))
Write-Output '--- bush blockstate (blackberry) ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $assets 'blockstates\plant\blackberry_bush.json')))

