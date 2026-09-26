$res = 'C:\Users\36958\Documents\AI\group\src\main\resources'
$root = Split-Path (Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent) -Parent
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$res = Join-Path $root 'src\main\resources'
$a = Join-Path $res 'assets\tfc_food_port'
$d = Join-Path $res 'data\tfc_food_port'

$bad = 0; $n = 0
# PS 5.1's ConvertFrom-Json chokes on the empty variant key "" used by property-less blockstates,
# so use the .NET Framework serialiser instead - it is a strict JSON parser.
Add-Type -AssemblyName System.Web.Extensions
$parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
Get-ChildItem $res -Recurse -File -Filter *.json | ForEach-Object {
  $n++; $p = $_.FullName
  try { [void]$parser.DeserializeObject([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)) }
  catch { $bad++; Write-Output ('INVALID: ' + $p.Replace($res + '\', '') + ' :: ' + $_.Exception.Message) }
}
Write-Output ("json total: $n   invalid: $bad")
Write-Output ("item models : " + (Get-ChildItem (Join-Path $a 'models\item') -Recurse -File).Count)
Write-Output ("block models: " + (Get-ChildItem (Join-Path $a 'models\block') -Recurse -File).Count)
Write-Output ("blockstates : " + (Get-ChildItem (Join-Path $a 'blockstates') -Recurse -File).Count)
Write-Output ("textures    : " + (Get-ChildItem (Join-Path $a 'textures') -Recurse -File).Count)
Write-Output ("loot tables : " + (Get-ChildItem (Join-Path $d 'loot_table') -Recurse -File).Count)
Write-Output ("recipes     : " + (Get-ChildItem (Join-Path $d 'recipe') -Recurse -File).Count)

$j = [System.IO.File]::ReadAllText((Join-Path $a 'lang\zh_cn.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$want = @('item.tfc_food_port.seeds.wheat', 'block.tfc_food_port.crop.wheat',
          'item.tfc_food_port.seeds.red_bell_pepper', 'block.tfc_food_port.crop.melon',
          'block.tfc_food_port.barrel', 'item.tfc_food_port.food.cheese')
foreach ($w in $want) {
  $p = $j.PSObject.Properties | Where-Object { $_.Name -eq $w }
  if ($p) { Write-Output ('  ' + $w + ' = ' + $p.Value) } else { Write-Output ('  MISSING ' + $w) }
}

# show the wheat structure so the shape can be eyeballed
Write-Output '--- crop/wheat blockstate ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $a 'blockstates\crop\wheat.json')))
Write-Output '--- crop/wheat loot table ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $d 'loot_table\blocks\crop\wheat.json')))
Write-Output '--- crop/red_bell_pepper loot table ---'
Write-Output ([System.IO.File]::ReadAllText((Join-Path $d 'loot_table\blocks\crop\red_bell_pepper.json')))
