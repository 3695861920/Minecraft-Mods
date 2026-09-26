$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent

Write-Output '=== source: items/food/cheese.json ==='
$p1 = Join-Path $root 'src\main\resources\assets\tfc_food_port\items\food\cheese.json'
if (Test-Path $p1) { [System.IO.File]::ReadAllText($p1, [System.Text.Encoding]::UTF8) } else { Write-Output '  MISSING' }

Write-Output '=== source: items/seeds/wheat.json ==='
$p2 = Join-Path $root 'src\main\resources\assets\tfc_food_port\items\seeds\wheat.json'
if (Test-Path $p2) { [System.IO.File]::ReadAllText($p2, [System.Text.Encoding]::UTF8) } else { Write-Output '  MISSING' }

Write-Output '=== source: items/plant/blackberry_bush.json ==='
$p3 = Join-Path $root 'src\main\resources\assets\tfc_food_port\items\plant\blackberry_bush.json'
if (Test-Path $p3) { [System.IO.File]::ReadAllText($p3, [System.Text.Encoding]::UTF8) } else { Write-Output '  MISSING' }

Write-Output '=== build/resources/main: does items/ exist there? ==='
$b = Join-Path $root 'build\resources\main\assets\tfc_food_port'
foreach ($sub in @('items', 'models\item', 'textures\item')) {
  $d = Join-Path $b $sub
  if (Test-Path $d) {
    Write-Output ('  ' + $sub + ' : ' + (Get-ChildItem $d -Recurse -File).Count + ' files')
  } else { Write-Output ('  ' + $sub + ' : MISSING') }
}
$bc = Join-Path $b 'items\food\cheese.json'
if (Test-Path $bc) { Write-Output '--- build copy of items/food/cheese.json ---'; [System.IO.File]::ReadAllText($bc, [System.Text.Encoding]::UTF8) } else { Write-Output '  build copy MISSING' }
