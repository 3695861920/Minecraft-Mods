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
Dump 'data/farmersdelight/recipe/cutting/melon.json'
Dump 'data/farmersdelight/recipe/cutting/pumpkin.json'
Dump 'data/farmersdelight/recipe/cutting/tag_dough.json'
Dump 'data/farmersdelight/recipe/cutting/kelp_roll.json'
$z.Dispose()
