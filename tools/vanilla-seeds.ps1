Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

function GrepSrc([string]$entry, [string]$pattern, [int]$ctx) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $entry } | Select-Object -First 1
  if (-not $e) { Write-Output ('MISSING ' + $entry); return }
  $sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  Write-Output ('===== ' + $entry + '  matching /' + $pattern + '/')
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $pattern) {
      $a = [Math]::Max(0, $i - $ctx); $b = [Math]::Min($lines.Count - 1, $i + $ctx)
      for ($j = $a; $j -le $b; $j++) { Write-Output ('  ' + ($j + 1).ToString().PadLeft(4) + ': ' + $lines[$j]) }
      Write-Output '  ---'
    }
  }
}

GrepSrc 'net/minecraft/world/item/Items.java' 'WHEAT_SEEDS|CARROT\s*=|POTATO\s*=|BEETROOT_SEEDS' 2
Write-Output ''
Write-Output '=== gametest structures available ==='
$z.Entries | Where-Object { $_.FullName -like 'data/*/structure/empty*' -or $_.FullName -like 'data/*/gametest/*' -or $_.FullName -like '*empty.nbt' } | ForEach-Object { Write-Output ('  ' + $_.FullName) }
$z.Dispose()
