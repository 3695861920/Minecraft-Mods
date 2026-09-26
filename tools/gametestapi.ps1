Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$src = (Get-ChildItem (Join-Path $root 'build\moddev\artifacts') -Filter 'minecraft-patched-*-sources.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($src)

$hit = $z.Entries | Where-Object { $_.FullName -like '*gametest/framework/GameTestHelper.java' } | Select-Object -First 1
Write-Output ('GameTestHelper entry: ' + ($(if ($hit) { $hit.FullName } else { 'NOT FOUND' })))
if ($hit) {
  $sr = New-Object System.IO.StreamReader($hit.Open()); $lines = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  foreach ($pat in @('makeMockPlayer', 'public .* setBlock\(', 'public void assertTrue', 'public .* absolutePos', 'public BlockState getBlockState')) {
    Write-Output ('--- /' + $pat + '/')
    $lines | Select-String -Pattern $pat | Select-Object -First 4 | ForEach-Object { Write-Output ('  ' + $_.LineNumber.ToString().PadLeft(5) + ': ' + $_.Line.Trim()) }
  }
}
Write-Output ''
Write-Output '=== UseOnContext constructors ==='
$e2 = $z.Entries | Where-Object { $_.FullName -like '*item/context/UseOnContext.java' } | Select-Object -First 1
if ($e2) {
  $sr = New-Object System.IO.StreamReader($e2.Open()); $lines2 = $sr.ReadToEnd() -split "`r?`n"; $sr.Close()
  $lines2 | Select-String -Pattern 'public UseOnContext' -Context 0,6 | Select-Object -First 3 | ForEach-Object { Write-Output ('  ' + $_.Line.Trim()); $_.Context.PostContext | ForEach-Object { Write-Output ('      ' + $_.Trim()) } }
} else { Write-Output '  UseOnContext not found' }
$z.Dispose()
