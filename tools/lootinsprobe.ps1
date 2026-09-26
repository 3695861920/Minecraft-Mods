Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($pat in @('*FarmersDelight*.jar', '*kaleidoscope*.jar', '*TerraFirmaCraft*.jar')) {
  $jar = (Get-ChildItem ('C:\Users\36958\Documents\AI\*\' + $pat) -File | Select-Object -First 1).FullName
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  $hits = New-Object System.Collections.Generic.List[string]
  foreach ($e in $z.Entries) {
    if ($e.Length -eq 0) { continue }
    if ($e.FullName -notlike 'data/*/loot_modifiers/*') { continue }
    $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
    foreach ($m in [regex]::Matches($t, '"loot_table_id"\s*:\s*"([^"]+)"')) { $hits.Add($m.Groups[1].Value) }
  }
  Write-Output ('### ' + (Split-Path $jar -Leaf))
  if ($hits.Count -eq 0) { Write-Output '  (no loot_table_id conditions)' }
  $hits | Sort-Object -Unique | ForEach-Object { Write-Output ('   ' + $_) }
  $z.Dispose()
}
