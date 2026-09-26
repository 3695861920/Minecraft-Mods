Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$e = $z.Entries | Where-Object { $_.FullName -eq 'META-INF/neoforge.mods.toml' }
if ($e) {
  $sr = New-Object System.IO.StreamReader($e.Open())
  Write-Output $sr.ReadToEnd()
  $sr.Close()
}
Write-Output "=== recipe json types ==="
$z.Entries | Where-Object { $_.FullName -like 'data/farmersdelight/recipe/*/*.json' } | ForEach-Object { ($_.FullName -split '/')[2] } | Sort-Object -Unique
Write-Output "=== recipe folders ==="
$z.Entries | Where-Object { $_.FullName -like 'data/farmersdelight/recipe/*' } | ForEach-Object { $_.FullName } | Select-Object -First 25
$z.Dispose()
