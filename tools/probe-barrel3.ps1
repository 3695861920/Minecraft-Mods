$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)

Write-Output '=== one per-wood barrel model (texture keys) ==='
$e = $z.Entries | Where-Object { $_.FullName -eq 'assets/tfc/models/block/wood/barrel/hickory.json' } | Select-Object -First 1
if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output $sr.ReadToEnd(); $sr.Close() }

Write-Output ''
Write-Output '=== plank textures (first 15) ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/wood/planks/*.png' } | ForEach-Object { $_.FullName.Substring(('assets/tfc/textures/block/wood/planks/').Length) } | Sort-Object | Select-Object -First 15 | ForEach-Object { Write-Output ('  ' + $_) }

Write-Output ''
Write-Output '=== sheet textures (first 15) ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/wood/sheet/*.png' } | ForEach-Object { $_.FullName.Substring(('assets/tfc/textures/block/wood/sheet/').Length) } | Sort-Object | Select-Object -First 15 | ForEach-Object { Write-Output ('  ' + $_) }

Write-Output ''
Write-Output '=== do hickory / oak / ash exist as planks + sheet? ==='
foreach ($w in @('hickory', 'oak', 'ash', 'birch', 'spruce', 'aspen')) {
  $p = ($z.Entries | Where-Object { $_.FullName -eq "assets/tfc/textures/block/wood/planks/$w.png" }) -ne $null
  $s = ($z.Entries | Where-Object { $_.FullName -eq "assets/tfc/textures/block/wood/sheet/$w.png" }) -ne $null
  Write-Output ("  $w : planks=$p sheet=$s")
}
$z.Dispose()
