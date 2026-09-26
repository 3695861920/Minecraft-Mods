$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$texDir = Join-Path $root 'src\main\resources\assets\tfc_food_port\textures\block\plant'

function Info([string]$path) {
  $b = [System.IO.File]::ReadAllBytes($path)
  $w = [int]$b[16] * 16777216 + [int]$b[17] * 65536 + [int]$b[18] * 256 + [int]$b[19]
  $h = [int]$b[20] * 16777216 + [int]$b[21] * 65536 + [int]$b[22] * 256 + [int]$b[23]
  return @($w, $h)
}

Write-Output '=== sapling / leaves texture dimensions ==='
Get-ChildItem $texDir -File -Filter *.png | Sort-Object Name | ForEach-Object {
  $d = Info $_.FullName
  $flag = ''
  if ($d[0] -ne 16 -or $d[1] -ne 16) { $flag = '   <-- NOT 16x16' }
  Write-Output ("  {0,-28} {1}x{2}  {3} bytes{4}" -f $_.Name, $d[0], $d[1], $_.Length, $flag)
}
