Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent

# ---- 1. full flower_plain configured feature ----
$merged = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\minecraft-patched-*-merged.jar') -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($merged)
$e = $z.Entries | Where-Object { $_.FullName -eq 'data/minecraft/worldgen/configured_feature/flower_plain.json' } | Select-Object -First 1
if ($e) { $sr = New-Object System.IO.StreamReader($e.Open()); Write-Output '===== flower_plain.json'; Write-Output $sr.ReadToEnd(); $sr.Close() }

Write-Output '=== all distinct outer feature types used by vanilla configured features ==='
$types = @{}
foreach ($en in $z.Entries) {
  if ($en.Length -eq 0 -or $en.FullName -notlike 'data/minecraft/worldgen/configured_feature/*.json') { continue }
  $sr = New-Object System.IO.StreamReader($en.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  $m = [regex]::Match($t, '"type"\s*:\s*"([^"]+)"')
  if ($m.Success) { $types[$m.Groups[1].Value] = 1 }
}
$types.Keys | Sort-Object | ForEach-Object { Write-Output ('  ' + $_) }

Write-Output ''
Write-Output '=== biome ids available ==='
$z.Entries | Where-Object { $_.FullName -like 'data/minecraft/worldgen/biome/*.json' } | ForEach-Object { $_ -replace '.*/', '' -replace '\.json$','' } | Sort-Object | ForEach-Object { Write-Output ('  ' + $_) }
$z.Dispose()

# ---- 2. feature registry names from decompiled sources ----
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts\') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
$e = $z2.Entries | Where-Object { $_.FullName -eq 'net/minecraft/world/level/levelgen/feature/Feature.java' } | Select-Object -First 1
if ($e) {
  $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
  Write-Output ''
  Write-Output '=== Feature.java registrations ==='
  [regex]::Matches($t, 'register\(\s*"([^"]+)"') | ForEach-Object { Write-Output ('  ' + $_.Groups[1].Value) }
} else { Write-Output 'Feature.java not found in sources jar' }
$z2.Dispose()
