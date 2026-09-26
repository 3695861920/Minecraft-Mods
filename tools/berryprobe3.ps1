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
Show $tfc @('assets/tfc/models/block/plant/blackberry_bush_0.json', 'assets/tfc/models/block/plant/fruiting_blackberry_bush_2.json')

$fd = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\FarmersDelight*.jar' -File | Select-Object -First 1).FullName
Show $fd @('data/farmersdelight/worldgen/configured_feature/patch_wild_beetroots.json',
            'data/farmersdelight/neoforge/biome_modifier/wild_beetroots.json',
            'data/farmersdelight/worldgen/placed_feature/wild_beetroots.json')
$z = [System.IO.Compression.ZipFile]::OpenRead($fd)
Write-Output '=== FD placed_feature list ==='
$z.Entries | Where-Object { $_.FullName -like 'data/farmersdelight/worldgen/placed_feature/*' } | ForEach-Object { $_.FullName.Split('/')[-1] }
$z.Dispose()
