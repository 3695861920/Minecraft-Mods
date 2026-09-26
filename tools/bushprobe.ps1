$fd = 'C:\Users\36958\Documents\AI\group\tools\src-fd\vectorwing\farmersdelight\common\block'
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$fd = Join-Path (Split-Path (Join-Path $root 'tools')) 'src-fd\vectorwing\farmersdelight\common\block'
foreach ($f in @('TomatoBlock.java', 'MushroomColonyBlock.java', 'HangingTomatoBlock.java', 'PieBlock.java')) {
  $p = Join-Path $fd $f
  if (Test-Path $p) {
    Write-Output ('===== ' + $f)
    Select-String -Path $p -Pattern 'class .* extends|protected .*InteractionResult|public .*InteractionResult|entityInside|randomTick|mayPlaceOn|isRandomlyTicking' | Select-Object -First 12 | ForEach-Object { Write-Output ('  ' + $_.LineNumber + ': ' + $_.Line.Trim()) }
  }
}
Write-Output '=== where is VegetationBlock / BushBlock used ==='
Get-ChildItem (Split-Path (Join-Path $root 'tools')) -Recurse -Filter *.java | Select-String -Pattern 'extends (VegetationBlock|BushBlock)|import net\.minecraft\.world\.level\.block\.(VegetationBlock|BushBlock)' | Select-Object -First 12 | ForEach-Object { Write-Output ('  ' + $_.Path + ' :: ' + $_.Line.Trim()) }
