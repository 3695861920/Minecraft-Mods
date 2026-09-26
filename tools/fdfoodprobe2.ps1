Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$recipes = @{}
foreach ($e in $z.Entries) {
  if ($e.Length -eq 0) { continue }
  if ($e.FullName -notlike 'data/farmersdelight/recipe/*') { continue }
  $sr = New-Object System.IO.StreamReader($e.Open()); $recipes[$e.FullName] = $sr.ReadToEnd(); $sr.Close()
}
$z.Dispose()

foreach ($needle in @('"id": "farmersdelight:wheat_dough"', 'flour', 'minecraft:water_bucket', 'minecraft:potion', '"minecraft:fluid"')) {
  Write-Output ('=== contains: ' + $needle + ' ===')
  $c = 0
  foreach ($k in ($recipes.Keys | Sort-Object)) {
    if ($recipes[$k] -like ('*' + $needle + '*')) { Write-Output ('--- ' + $k); Write-Output $recipes[$k]; $c++; if ($c -ge 2) { break } }
  }
  if ($c -eq 0) { Write-Output '  (none)' }
}
