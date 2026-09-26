$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem

$fruits = @('banana', 'orange', 'lemon', 'peach', 'cherry', 'olive', 'green_apple', 'red_apple', 'plum')
$texDir = Join-Path $root 'src\main\resources\assets\tfc_food_port\textures\block\plant'

$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)
$names = $z.Entries | ForEach-Object { $_.FullName }

Write-Output '=== per fruit: TFC source present? copied file valid? ==='
foreach ($f in $fruits) {
  foreach ($kind in @(@('sapling', "$f`_sapling"), @('leaves', "$f`_leaves"))) {
    $src = "assets/tfc/textures/block/fruit_tree/$f`_$($kind[0]).png"
    $inTfc = $names -contains $src
    $out = Join-Path $texDir ($kind[1] + '.png')
    $exists = Test-Path $out
    $ok = 'n/a'; $size = 0; $magic = ''
    if ($exists) {
      $b = [System.IO.File]::ReadAllBytes($out)
      $size = $b.Length
      $magic = ($b[0..7] | ForEach-Object { $_.ToString('X2') }) -join ' '
      $tail = ($b[($b.Length - 8)..($b.Length - 1)] | ForEach-Object { $_.ToString('X2') }) -join ' '
      $ok = ($magic -eq '89 50 4E 47 0D 0A 1A 0A' -and $tail -eq '49 45 4E 44 AE 42 60 82')
    }
    Write-Output ("  {0,-12} {1,-8} tfc={2,-5} copied={3,-5} valid={4,-5} size={5}" -f $f, $kind[0], $inTfc, $exists, $ok, $size)
  }
}

Write-Output ''
Write-Output '=== all TFC fruit_tree textures available ==='
$names | Where-Object { $_ -like 'assets/tfc/textures/block/fruit_tree/*' } | ForEach-Object { '  ' + $_.Split('/')[-1] } | Sort-Object

Write-Output ''
Write-Output '=== our generated sapling models (check texture path inside) ==='
foreach ($f in $fruits) {
  $p = Join-Path $root "src\main\resources\assets\tfc_food_port\models\block\plant\$f`_sapling.json"
  if (Test-Path $p) { Write-Output ('  ' + $f + ': ' + ([System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) -replace '\s+', ' ')) }
  else { Write-Output ('  ' + $f + ': MODEL MISSING') }
}
$z.Dispose()
