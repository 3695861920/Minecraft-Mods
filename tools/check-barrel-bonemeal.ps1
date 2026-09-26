$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$r = Join-Path $root 'src\main\resources\data\tfc_food_port\recipe'

Write-Output '=== top-level recipes in src ==='
Get-ChildItem $r -File | ForEach-Object { Write-Output ('  ' + $_.Name) }
Write-Output ('  top-level count: ' + (Get-ChildItem $r -File).Count)

Write-Output ''
Write-Output '=== is barrel.json there? ==='
$b = Join-Path $r 'barrel.json'
Write-Output ('  ' + (Test-Path $b))

Write-Output ''
Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem (Join-Path $root 'build\libs\*.jar') -File | Where-Object { $_.Name -notlike '*sources*' } | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
Write-Output '=== barrel recipe inside the built jar? ==='
$e = $z.Entries | Where-Object { $_.FullName -eq 'data/tfc_food_port/recipe/barrel.json' }
Write-Output ('  ' + $(if ($e) { 'PRESENT' } else { 'ABSENT' }))
$z.Dispose()

# ---- vanilla sweet berry bush, for the bone meal API ----
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
$e2 = $z2.Entries | Where-Object { $_.FullName -like '*SweetBerryBushBlock.java' } | Select-Object -First 1
if ($e2) {
  $sr = New-Object System.IO.StreamReader($e2.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  Write-Output ''
  Write-Output ('===== ' + $e2.FullName)
  Write-Output $t
} else { Write-Output 'SweetBerryBushBlock not found' }
$z2.Dispose()
