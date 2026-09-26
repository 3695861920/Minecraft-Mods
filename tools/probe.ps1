Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem -Path 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
Write-Output ("JAR: " + $jar)
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
Write-Output ("Total entries: " + $z.Entries.Count)
Write-Output ("class files: " + ($z.Entries | Where-Object { $_.FullName -like '*.class' }).Count)
Write-Output "--- lang files ---"
$z.Entries | Where-Object { $_.FullName -like 'assets/*/lang/*' } | ForEach-Object { $_.FullName + "  (" + $_.Length + ")" }
Write-Output "--- top level dirs ---"
$z.Entries | ForEach-Object { ($_.FullName -split '/')[0..1] -join '/' } | Sort-Object -Unique | Select-Object -First 60
Write-Output "--- barrels/blockentity candidates ---"
$z.Entries | Where-Object { $_.FullName -match '(Barrel|Crop|Seed)' } | ForEach-Object { $_.FullName } | Select-Object -First 80
$z.Dispose()
