$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$res = Join-Path $root 'src\main\resources'
$a = Join-Path $res 'assets\tfc_food_port'
$d = Join-Path $res 'data\tfc_food_port'

Add-Type -AssemblyName System.Web.Extensions
$parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$bad = 0; $n = 0
Get-ChildItem $res -Recurse -File -Filter *.json | ForEach-Object {
  $n++
  try { [void]$parser.DeserializeObject([System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)) }
  catch { $bad++; Write-Output ('INVALID: ' + $_.FullName.Replace($res + '\', '')) }
}
Write-Output '=========== FINAL ==========='
Write-Output ("json files        : $n   (invalid: $bad)")
Write-Output ("java classes      : " + (Get-ChildItem (Join-Path $root 'src\main\java') -Recurse -File -Filter *.java).Count)
Write-Output ("item models       : " + (Get-ChildItem (Join-Path $a 'models\item') -Recurse -File).Count)
Write-Output ("block models      : " + (Get-ChildItem (Join-Path $a 'models\block') -Recurse -File).Count)
Write-Output ("blockstates       : " + (Get-ChildItem (Join-Path $a 'blockstates') -Recurse -File).Count)
Write-Output ("textures          : " + (Get-ChildItem (Join-Path $a 'textures') -Recurse -File).Count)
Write-Output ("recipes           : " + (Get-ChildItem (Join-Path $d 'recipe') -Recurse -File).Count)
Write-Output ("loot tables       : " + (Get-ChildItem (Join-Path $d 'loot_table') -Recurse -File).Count)
Write-Output ("loot modifiers    : " + (Get-ChildItem (Join-Path $d 'loot_modifiers') -Recurse -File).Count)
Write-Output ("configured feature: " + (Get-ChildItem (Join-Path $d 'worldgen\configured_feature') -Recurse -File).Count)
Write-Output ("placed feature    : " + (Get-ChildItem (Join-Path $d 'worldgen\placed_feature') -Recurse -File).Count)
Write-Output ("biome modifiers   : " + (Get-ChildItem (Join-Path $d 'neoforge\biome_modifier') -Recurse -File).Count)
Write-Output ("common item tags  : " + (Get-ChildItem (Join-Path $res 'data\c\tags') -Recurse -File).Count)

$j = [System.IO.File]::ReadAllText((Join-Path $a 'lang\zh_cn.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$je = [System.IO.File]::ReadAllText((Join-Path $a 'lang\en_us.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
Write-Output ("lang keys zh/en   : " + $j.PSObject.Properties.Count + ' / ' + $je.PSObject.Properties.Count)
