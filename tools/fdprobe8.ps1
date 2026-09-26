Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($pat in @('*FarmersDelight*.jar', '*kaleidoscope*.jar')) {
  $jar = (Get-ChildItem ('C:\Users\36958\Documents\AI\*\' + $pat) -File | Select-Object -First 1).FullName
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  Write-Output ('### ' + (Split-Path $jar -Leaf))
  $shown = 0
  foreach ($e in $z.Entries) {
    if ($e.Length -eq 0) { continue }
    if ($e.FullName -notlike 'assets/*/blockstates/*') { continue }
    $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
    if ($t -match '"variants"\s*:\s*\{\s*""') {
      Write-Output ('===== ' + $e.FullName)
      Write-Output $t
      $shown++
      if ($shown -ge 1) { break }
    }
  }
  if ($shown -eq 0) { Write-Output '  (no empty-key blockstate found)' }
  $z.Dispose()
}
