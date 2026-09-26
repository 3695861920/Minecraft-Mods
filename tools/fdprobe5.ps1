Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
function Dump($path) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $path } | Select-Object -First 1
  if ($e) {
    $sr = New-Object System.IO.StreamReader($e.Open())
    Write-Output ("===== " + $path)
    Write-Output $sr.ReadToEnd()
    $sr.Close()
  } else { Write-Output ("MISSING " + $path) }
}
Write-Output "=== loot table candidates ==="
$z.Entries | Where-Object { $_.FullName -like 'data/farmersdelight/loot_table/*' } | ForEach-Object { $_.FullName } | Select-Object -First 10
Write-Output "=== blockstate sample ==="
$z.Entries | Where-Object { $_.FullName -like 'assets/farmersdelight/blockstates/*' } | ForEach-Object { $_.FullName } | Select-Object -First 5
Dump 'data/farmersdelight/loot_table/blocks/cooking_pot.json'
Dump 'assets/farmersdelight/blockstates/cooking_pot.json'
$z.Dispose()
