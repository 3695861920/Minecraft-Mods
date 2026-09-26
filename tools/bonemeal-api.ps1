$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

foreach ($f in @('net/minecraft/world/level/block/SweetBerryBushBlock.java', 'net/minecraft/world/level/block/BonemealableBlock.java')) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $f } | Select-Object -First 1
  if (-not $e) { Write-Output ('MISSING ' + $f); continue }
  $sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  Write-Output ('===== ' + $f)
  if ($f -like '*BonemealableBlock') {
    $lines | Select-String -Pattern 'boolean isValidBonemealTarget|boolean isBonemealSuccess|void performBonemeal|interface BonemealableBlock|default boolean|boolean canBeBonemealed' -Context 0,2 | ForEach-Object { Write-Output ('  ' + $_.Line.Trim()); $_.Context.PostContext | ForEach-Object { Write-Output ('      ' + $_.Trim()) } }
  } else {
    # print everything from "public boolean" onward (the bonemeal block)
    $start = ($lines | Select-String -Pattern 'isValidBonemealTarget' | Select-Object -First 1).LineNumber
    if ($start) { for ($i = $start - 3; $i -lt $lines.Count; $i++) { Write-Output ('  ' + ($i + 1).ToString().PadLeft(4) + ': ' + $lines[$i]) } }
    else { Write-Output '  (no isValidBonemealTarget found)' }
  }
}
$z.Dispose()
