$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

$e = $z.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/level/storage/ValueOutput.java' } | Select-Object -First 1
if ($e) {
  $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  Write-Output '===== ValueOutput.java'
  Write-Output $t
} else { Write-Output 'ValueOutput.java not found' }

Write-Output ''
Write-Output '=== TagValueOutput: how child() is implemented ==='
$e2 = $z.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/level/storage/TagValueOutput.java' } | Select-Object -First 1
if ($e2) {
  $sr = New-Object System.IO.StreamReader($e2.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  $lines | Select-String -Pattern 'public ValueOutput child|child\(|ValueOutput createChild|store\(|private' | Select-Object -First 25 | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(4) + ': ' + $_.Line.Trim()) }
} else { Write-Output 'TagValueOutput.java not found' }
$z.Dispose()
