Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
Write-Output "=== blockstates: crop/wheat ==="
$z.Entries | Where-Object { $_.FullName -eq 'assets/tfc/blockstates/crop/wheat.json' } | ForEach-Object {
  $sr = New-Object System.IO.StreamReader($_.Open()); Write-Output $sr.ReadToEnd(); $sr.Close()
}
Write-Output "=== block textures under block/crop (wheat only) ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/crop/wheat*' } | ForEach-Object { $_.FullName }
Write-Output "=== any crop model dir ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/models/block/crop/*' } | ForEach-Object { $_.FullName } | Select-Object -First 12
Write-Output "=== seeds textures ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/item/seeds/*' } | ForEach-Object { $_.FullName } | Select-Object -First 8
$z.Dispose()
