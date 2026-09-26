$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

function Show([string]$file, [string]$pat, [int]$n) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $file } | Select-Object -First 1
  if (-not $e) { Write-Output ('MISSING ' + $file); return }
  $sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  Write-Output ('===== ' + $file + '   /' + $pat + '/')
  $lines | Select-String -Pattern $pat | Select-Object -First $n | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(4) + ': ' + $_.Line.Trim()) }
}

# how does a bucket behave when right clicking a block?
Show 'net/minecraft/world/item/BucketItem.java' 'public InteractionResult use|interactWithFluidHandler|getFluidHandler|tryPlaceFluid|emptyContents|public InteractionResult useOn' 12

# is BlockState#useItemOn reachable for a test?
Show 'net/minecraft/world/level/block/state/BlockState.java' 'useItemOn|useWithoutItem' 8

$z.Dispose()
