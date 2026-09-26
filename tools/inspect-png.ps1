Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$texDir = Join-Path $root 'src\main\resources\assets\tfc_food_port\textures'

$p = Join-Path $texDir 'block\crop\cabbage_0.png'
Write-Output ('on-disk size : ' + (Get-Item $p).Length)
$b = [System.IO.File]::ReadAllBytes($p)
Write-Output ('first bytes  : ' + (($b[0..([Math]::Min(23, $b.Length - 1))] | ForEach-Object { $_.ToString('X2') }) -join ' '))

# what does the source entry look like inside the TFC jar?
$jar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
foreach ($name in @('assets/tfc/textures/block/crop/cabbage_0.png',
                    'assets/tfc/textures/block/crop/cabbage_1.png')) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $name } | Select-Object -First 1
  if ($e) {
    $s = $e.Open(); $b2 = New-Object byte[] ([int]$e.Length); [void]$s.Read($b2, 0, $b2.Length); $s.Close()
    $tail = ($b2[($b2.Length - 8)..($b2.Length - 1)] | ForEach-Object { $_.ToString('X2') }) -join ' '
    Write-Output ("SOURCE $name  length=$($e.Length)  IEND=$tail")
  } else { Write-Output ("SOURCE MISSING $name") }
}
$z.Dispose()

# also list every texture under 200 bytes, to catch any other suspicious ones
Write-Output ''
Write-Output '=== all textures smaller than 200 bytes ==='
Get-ChildItem $texDir -Recurse -File -Filter *.png | Where-Object { $_.Length -lt 200 } | ForEach-Object {
  Write-Output ('  ' + $_.Length + '  ' + $_.FullName.Substring($texDir.Length + 1))
}
