$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$f = Join-Path $root 'src\main\java\com\tfc_food_port\common\block\TFCBerryBushBlock.java'

# Set-Content -Encoding UTF8 writes a BOM, which javac rejects ("illegal character: '\ufeff'").
# Strip it and write back as UTF-8 without BOM.
$bytes = [System.IO.File]::ReadAllBytes($f)
$bom = @(0xEF, 0xBB, 0xBF)
$hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq $bom[0] -and $bytes[1] -eq $bom[1] -and $bytes[2] -eq $bom[2]
Write-Output ('BOM present: ' + $hasBom)

$text = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
$text = $text.TrimStart([char]0xFEFF)
$text = $text -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($f, $text, (New-Object System.Text.UTF8Encoding($false)))

$bytes2 = [System.IO.File]::ReadAllBytes($f)
$stillBom = $bytes2.Length -ge 3 -and $bytes2[0] -eq 0xEF -and $bytes2[1] -eq 0xBB -and $bytes2[2] -eq 0xBF
Write-Output ('BOM after fix: ' + $stillBom)

# check every java file for a BOM, they must all be clean
$bad = 0
Get-ChildItem (Join-Path $root 'src\main\java') -Recurse -File -Filter *.java | ForEach-Object {
  $b = [System.IO.File]::ReadAllBytes($_.FullName)
  if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
    Write-Output ('BOM in ' + $_.Name)
    $bad++
  }
}
Write-Output ("java files with a BOM: $bad")
