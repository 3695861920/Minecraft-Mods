Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($jar in @((Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName,
                   (Get-ChildItem 'C:\Users\36958\Documents\AI\*\kaleidoscope*.jar' -File | Select-Object -First 1).FullName)) {
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  Write-Output ("### " + (Split-Path $jar -Leaf))
  $found = 0
  foreach ($e in $z.Entries) {
    if ($e.Length -eq 0) { continue }
    if ($e.FullName -notlike 'data/*/loot_table/*') { continue }
    $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
    if ($t -like '*"minecraft:uniform"*') {
      Write-Output ("===== " + $e.FullName)
      $i = $t.IndexOf('minecraft:uniform')
      $start = [Math]::Max(0, $i - 320)
      Write-Output $t.Substring($start, [Math]::Min(520, $t.Length - $start))
      $found++
      if ($found -ge 1) { break }
    }
  }
  if ($found -eq 0) { Write-Output "  (no uniform loot found)" }
  $z.Dispose()
}
