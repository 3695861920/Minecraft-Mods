Add-Type -AssemblyName System.IO.Compression.FileSystem

function Show([string]$jar, [string[]]$paths) {
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  foreach ($p in $paths) {
    $e = $z.Entries | Where-Object { $_.FullName -eq $p } | Select-Object -First 1
    if ($e) {
      $sr = New-Object System.IO.StreamReader($e.Open())
      Write-Output ('===== ' + $p)
      Write-Output $sr.ReadToEnd()
      $sr.Close()
    } else { Write-Output ('MISSING ' + $p) }
  }
  $z.Dispose()
}

$tfc = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
Show $tfc @('assets/tfc/models/block/plant/berry_bush/blackberry_bush.json',
            'assets/tfc/blockstates/plant/blackberry_bush.json',
            'assets/tfc/models/block/plant/blackberry_bush.json')

$fd = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($fd)
Write-Output '=== FD worldgen files ==='
$z.Entries | Where-Object { $_.FullName -like 'data/farmersdelight/worldgen/*' } | ForEach-Object { $_.FullName } | Select-Object -First 12
$z.Entries | Where-Object { $_.FullName -like 'data/*/biome_modifier/*' } | ForEach-Object { $_.FullName } | Select-Object -First 12
$z.Dispose()
