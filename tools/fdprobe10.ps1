Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($pat in @('*FarmersDelight*.jar', '*kaleidoscope*.jar')) {
  $jar = (Get-ChildItem ('C:\Users\36958\Documents\AI\*\' + $pat) -File | Select-Object -First 1).FullName
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  $hits = New-Object System.Collections.Generic.List[string]
  foreach ($e in $z.Entries) {
    if ($e.Length -eq 0) { continue }
    if ($e.FullName -notlike 'data/*/loot_table/*') { continue }
    $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
    if ($t -match '"type"\s*:\s*"minecraft:generic"') { $hits.Add($e.FullName) }
  }
  Write-Output ('### ' + (Split-Path $jar -Leaf) + '  generic tables: ' + $hits.Count)
  $hits | Select-Object -First 3 | ForEach-Object { Write-Output ('   ' + $_) }
  $z.Dispose()
}
