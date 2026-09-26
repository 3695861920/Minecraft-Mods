$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path (Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent) -Parent
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$texDir = Join-Path $root 'src\main\resources\assets\tfc_food_port\textures\item'

function New-Placeholder {
  param([string]$OutPath, [int[][]]$Rows, [string]$Fill, [string]$Edge, [string[]]$Speckles)
  $dir = Split-Path $OutPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp = New-Object System.Drawing.Bitmap 16, 16
  for ($y = 0; $y -lt 16; $y++) {
    for ($x = 0; $x -lt 16; $x++) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)) }
  }
  $sp = @()
  if ($Speckles) { $sp = $Speckles }
  foreach ($row in $Rows) {
    $y = $row[0]; $x0 = $row[1]; $x1 = $row[2]
    for ($x = $x0; $x -le $x1; $x++) {
      $color = $Fill
      if ($x -eq $x0 -or $x -eq $x1) { $color = $Edge }
      $key = "$x,$y"
      if ($sp -contains $key) { $color = $Edge }
      $c = [System.Drawing.ColorTranslator]::FromHtml('#' + $color)
      $bmp.SetPixel($x, $y, $c)
    }
  }
  # top and bottom edges of every column range
  foreach ($row in $Rows) {
    $y = $row[0]
    if ($y -eq $Rows[0][0] -or $y -eq $Rows[-1][0]) {
      for ($x = $row[1]; $x -le $row[2]; $x++) {
        $bmp.SetPixel($x, $y, [System.Drawing.ColorTranslator]::FromHtml('#' + $Edge))
      }
    }
  }
  $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output ('wrote ' + $OutPath)
}

# curd: a soft cream coloured lump
$curdRows = @(
  ,@(4, 5, 10)
  ,@(5, 4, 11)
  ,@(6, 3, 12)
  ,@(7, 3, 12)
  ,@(8, 3, 12)
  ,@(9, 3, 12)
  ,@(10, 3, 12)
  ,@(11, 4, 11)
  ,@(12, 5, 10)
)
New-Placeholder -OutPath (Join-Path $texDir 'food\cheese_curd.png') -Rows $curdRows -Fill 'F7F2E1' -Edge 'CFC4A6' -Speckles @('5,7', '10,9', '7,11')

# rennet: a small tan powder pile
$rennetRows = @(
  ,@(6, 7, 8)
  ,@(7, 6, 9)
  ,@(8, 5, 10)
  ,@(9, 5, 10)
  ,@(10, 4, 11)
  ,@(11, 4, 11)
  ,@(12, 3, 12)
)
New-Placeholder -OutPath (Join-Path $texDir 'rennet.png') -Rows $rennetRows -Fill 'DFCCA6' -Edge 'BAA378' -Speckles @('6,8', '9,10', '7,12')
