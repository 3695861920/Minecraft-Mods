Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$res = Join-Path $root 'src\main\resources'
$jar = (Get-ChildItem (Join-Path $root 'build\libs\*.jar') -File | Where-Object { $_.Name -notlike '*sources*' } | Select-Object -First 1).FullName

$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$inJar = @{}
foreach ($e in $z.Entries) {
  if ($e.Length -eq 0) { continue }
  if ($e.FullName -notlike 'assets/tfc_food_port/*' -and $e.FullName -notlike 'data/tfc_food_port/*') { continue }
  $inJar[$e.FullName] = 1
}
$z.Dispose()

$onDisk = @{}
Get-ChildItem $res -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($res.Length + 1) -replace '\\', '/'
  if ($rel -like 'assets/tfc_food_port/*' -or $rel -like 'data/tfc_food_port/*') { $onDisk[$rel] = 1 }
}

Write-Output ("in jar    : " + $inJar.Count)
Write-Output ("on disk   : " + $onDisk.Count)
Write-Output ''
Write-Output '=== STALE: present in the jar but no longer in src (old build leftovers) ==='
$stale = $inJar.Keys | Where-Object { -not $onDisk.ContainsKey($_) } | Sort-Object
Write-Output ('  count: ' + @($stale).Count)
$stale | ForEach-Object { Write-Output ('   ' + $_) }
Write-Output ''
Write-Output '=== MISSING from the jar (present in src but not packaged) ==='
$missing = $onDisk.Keys | Where-Object { -not $inJar.ContainsKey($_) } | Sort-Object
Write-Output ('  count: ' + @($missing).Count)
$missing | ForEach-Object { Write-Output ('   ' + $_) }
