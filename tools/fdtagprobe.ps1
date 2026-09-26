Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
Write-Output '=== FD c: tags shipped ==='
$z.Entries | Where-Object { $_.FullName -like 'data/c/tags/*' } | ForEach-Object { $_.FullName } | Sort-Object | Select-Object -First 40
Write-Output '=== FD knife tag content ==='
$e = $z.Entries | Where-Object { $_.FullName -eq 'data/c/tags/item/tools/knife.json' } | Select-Object -First 1
if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output $sr.ReadToEnd(); $sr.Close() } else { Write-Output 'MISSING data/c/tags/item/tools/knife.json' }
$z.Dispose()
