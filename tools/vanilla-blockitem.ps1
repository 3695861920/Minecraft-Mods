Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($src)
$e = $z.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/item/Items.java' } | Select-Object -First 1
$sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
$z.Dispose()

Write-Output '=== definition of createBlockItemWithCustomItemName ==='
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'static\s+Item\s+createBlockItemWithCustomItemName' -or $lines[$i] -match 'createBlockItemWithCustomItemName\(Block') {
    if ($lines[$i] -match 'private|static Item|protected') {
      for ($j = $i; $j -le [Math]::Min($lines.Count - 1, $i + 6); $j++) { Write-Output ('  ' + ($j + 1).ToString().PadLeft(5) + ': ' + $lines[$j]) }
      Write-Output '  ---'
    }
  }
}
