Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$names = $z.Entries | Where-Object { $_.FullName -like 'data/farmersdelight/recipe/*.json' } | ForEach-Object { $_.FullName }
Write-Output ("total recipes: " + $names.Count)
Write-Output "=== cooking/cutting candidates ==="
$names | Where-Object { $_ -match 'cooking|cutting|_from_cutting|skillet' } | Select-Object -First 40
function Dump($path) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $path } | Select-Object -First 1
  if ($e) {
    $sr = New-Object System.IO.StreamReader($e.Open())
    Write-Output ("== " + $path)
    Write-Output $sr.ReadToEnd()
    $sr.Close()
  }
}
Dump 'data/farmersdelight/recipe/beef_patty.json'
Dump 'data/farmersdelight/recipe/bread_from_smelting.json'
Dump 'data/farmersdelight/recipe/cabbage.json'
Dump 'data/farmersdelight/recipe/apple_pie.json'
Dump 'data/farmersdelight/recipe/beetroot_from_crate.json'
$z.Dispose()
