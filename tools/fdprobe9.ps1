Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
function Dump($path) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $path } | Select-Object -First 1
  if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output ("===== " + $path); Write-Output $sr.ReadToEnd(); $sr.Close() }
  else { Write-Output ("MISSING " + $path) }
}
Write-Output '=== loot table types used by FD ==='
$types = @{}
foreach ($e in $z.Entries) {
  if ($e.Length -eq 0) { continue }
  if ($e.FullName -notlike 'data/farmersdelight/loot_table/*') { continue }
  $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  if ($t -match '"type"\s*:\s*"([^"]+)"') { $types[$Matches[1]] = 1 }
}
$types.Keys | Sort-Object
Dump 'data/farmersdelight/loot_table/chests/fd_village_butcher.json'
$z.Dispose()
