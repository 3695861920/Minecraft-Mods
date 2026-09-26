$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

function Sig([string]$file, [string]$pat, [int]$n) {
  $e = $z.Entries | Where-Object { $_.FullName -eq $file } | Select-Object -First 1
  if (-not $e) { Write-Output ('MISSING ' + $file); return }
  $sr = New-Object System.IO.StreamReader($e.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  Write-Output ('===== ' + $file)
  $lines | Select-String -Pattern $pat | Select-Object -First $n | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(4) + ': ' + $_.Line.Trim()) }
}

Sig 'net/minecraft/world/level/block/CropBlock.java' 'class CropBlock|BonemealableBlock|isValidBonemealTarget|performBonemeal|isBonemealSuccess' 8
Sig 'net/minecraft/world/level/block/entity/BlockEntity.java' 'public .*saveWithoutMetadata|public .*saveWithFullMetadata|public .*saveWithId|public .*loadWithComponents|protected void saveAdditional|protected void loadAdditional|public void setChanged' 12
$z.Dispose()
