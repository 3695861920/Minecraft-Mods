Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$names = $z.Entries | ForEach-Object { $_.FullName }

Write-Output '=== berry bush textures ==='
$names | Where-Object { $_ -match 'berry' -and $_ -like 'assets/tfc/textures/*' } | Sort-Object | Select-Object -First 40

Write-Output '=== berry bush blockstates ==='
$names | Where-Object { $_ -match 'berry' -and $_ -like 'assets/tfc/blockstates/*' } | Sort-Object | Select-Object -First 20

Write-Output '=== berry bush models ==='
$names | Where-Object { $_ -match 'berry' -and $_ -like 'assets/tfc/models/block/*' } | Sort-Object | Select-Object -First 20

Write-Output '=== berry_bush_classes ==='
$names | Where-Object { $_ -match 'BerryBush' } | Sort-Object | Select-Object -First 20

Write-Output '=== fruit tree / fruit textures ==='
$names | Where-Object { $_ -match 'fruit|leaves' -and $_ -like 'assets/tfc/textures/block/*' } | Sort-Object | Select-Object -First 40
$z.Dispose()
