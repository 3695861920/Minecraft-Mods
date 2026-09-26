Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
Write-Output "=== textures/item subdirs ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/item/*' } | ForEach-Object {
  $rest = $_.FullName.Substring('assets/tfc/textures/item/'.Length)
  if ($rest -match '/') { ($rest -split '/')[0] + '/' } else { $rest }
} | Sort-Object -Unique
Write-Output "=== textures/item/food sample ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/item/food/*' } | ForEach-Object { $_.FullName } | Select-Object -First 15
Write-Output ("count food textures: " + ($z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/item/food/*' }).Count)
Write-Output "=== textures/item/jar sample ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/item/jar/*' } | ForEach-Object { $_.FullName } | Select-Object -First 8
Write-Output "=== block textures barrel ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/*barrel*' } | ForEach-Object { $_.FullName }
$z.Dispose()
