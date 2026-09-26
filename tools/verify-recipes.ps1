$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$root = Split-Path $jar -Parent
$res = Join-Path $root 'src\main\resources'

Add-Type -AssemblyName System.Web.Extensions
$parser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$bad = 0; $n = 0
Get-ChildItem $res -Recurse -File -Filter *.json | ForEach-Object {
  $n++; $p = $_.FullName
  try { [void]$parser.DeserializeObject([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)) }
  catch { $bad++; Write-Output ('INVALID: ' + $p.Replace($res + '\', '') + ' :: ' + $_.Exception.Message) }
}
Write-Output ("json total: $n   invalid: $bad")

# every recipe should reference only ids we actually register
$known = New-Object System.Collections.Generic.HashSet[string]
Get-ChildItem (Join-Path $res 'assets\tfc_food_port\models\item') -Recurse -File -Filter *.json | ForEach-Object {
  $rel = $_.FullName.Substring((Join-Path $res 'assets\tfc_food_port\models\item').Length + 1) -replace '\\', '/'
  [void]$known.Add('tfc_food_port:' + ($rel -replace '\.json$', ''))
}
Write-Output ('known item ids from models: ' + $known.Count)

$dangling = New-Object System.Collections.Generic.List[string]
Get-ChildItem (Join-Path $res 'data\tfc_food_port\recipe') -Recurse -File -Filter *.json | ForEach-Object {
  $text = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($text, '"tfc_food_port:[a-z0-9_/]+"')) {
    $id = $m.Value.Trim('"')
    if (-not $known.Contains($id)) { $dangling.Add($_.Name + ' -> ' + $id) }
  }
}
if ($dangling.Count -gt 0) {
  Write-Output '--- recipe ids with no item model (item may not exist) ---'
  $dangling | Sort-Object -Unique | ForEach-Object { Write-Output ('  ' + $_) }
} else {
  Write-Output 'all tfc_food_port ids referenced by recipes have an item model'
}

Write-Output ("recipes: " + (Get-ChildItem (Join-Path $res 'data\tfc_food_port\recipe') -Recurse -File).Count)
Write-Output ("tags   : " + (Get-ChildItem (Join-Path $res 'data\c\tags') -Recurse -File).Count)
