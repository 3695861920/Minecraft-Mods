Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$hit = $null
foreach ($e in $z.Entries) {
  if ($e.FullName -like 'data/farmersdelight/loot_table/*' -and $e.Length -gt 0) {
    $sr = New-Object System.IO.StreamReader($e.Open())
    $t = $sr.ReadToEnd()
    $sr.Close()
    if ($t -like '*set_count*') { $hit = $e.FullName; Write-Output ("===== " + $e.FullName); Write-Output $t; break }
  }
}
if (-not $hit) { Write-Output "no set_count found; dumping a crop-like loot table" }
$e = $z.Entries | Where-Object { $_.FullName -eq 'data/farmersdelight/loot_table/blocks/tomato_crop.json' } | Select-Object -First 1
if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output "===== tomato_crop"; Write-Output $sr.ReadToEnd(); $sr.Close() }
$z.Dispose()
