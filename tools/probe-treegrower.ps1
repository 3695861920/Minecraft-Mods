$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

$e = $z.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/level/block/grower/TreeGrower.java' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
Write-Output '=== TreeGrower.java lines 26..120 ==='
for ($i = 25; $i -lt [Math]::Min(120, $lines.Count); $i++) { Write-Output ('  ' + ($i + 1).ToString().PadLeft(4) + ': ' + $lines[$i]) }

Write-Output ''
Write-Output '=== SaplingBlock full ==='
$e2 = $z.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/level/block/SaplingBlock.java' } | Select-Object -First 1
$sr2 = New-Object System.IO.StreamReader($e2.Open()); $t2 = $sr2.ReadToEnd(); $sr2.Close()
Write-Output $t2
$z.Dispose()
