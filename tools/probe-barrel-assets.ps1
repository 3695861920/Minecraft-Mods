$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$tfcJar = (Get-ChildItem (Join-Path $root '*TerraFirmaCraft*.jar') -File | Select-Object -First 1).FullName

# ---- 1. TFC barrel resources ----
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($tfcJar)
Write-Output '=== TFC block textures matching "barrel" (excluding cactus) ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/textures/block/*barrel*' } | ForEach-Object { Write-Output ('  ' + $_.FullName) }
Write-Output ''
Write-Output '=== TFC models matching "barrel" ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/models/*barrel*' } | ForEach-Object { Write-Output ('  ' + $_.FullName) }
Write-Output ''
Write-Output '=== TFC blockstates matching "barrel" ==='
$z.Entries | Where-Object { $_.FullName -like 'assets/tfc/blockstates/*barrel*' } | ForEach-Object { Write-Output ('  ' + $_.FullName) }
Write-Output ''
Write-Output '=== any texture under a barrel folder ==='
$z.Entries | Where-Object { $_.FullName -match 'barrel/' } | ForEach-Object { Write-Output ('  ' + $_.FullName) }
$z.Dispose()

# ---- 2. BlockBehaviour / BlockState useItemOn signature ----
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z2 = [System.IO.Compression.ZipFile]::OpenRead($src)
Write-Output ''
Write-Output '=== declarations of useItemOn ==='
foreach ($en in $z2.Entries) {
  if ($en.Length -eq 0 -or $en.FullName -notlike '*.java') { continue }
  if ($en.FullName -notmatch 'BlockBehaviour|BlockState|Block\.java') { continue }
  $sr = New-Object System.IO.StreamReader($en.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'InteractionResult\s+useItemOn\s*\(') {
      Write-Output ('  ' + $en.FullName + ':' + ($i + 1))
      Write-Output ('      ' + $lines[$i].Trim())
    }
  }
}
$z2.Dispose()
