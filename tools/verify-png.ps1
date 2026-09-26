$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$texDir = Join-Path $root 'src\main\resources\assets\tfc_food_port\textures'

$bad = 0; $n = 0
$sizes = @{}
Get-ChildItem $texDir -Recurse -File -Filter *.png | ForEach-Object {
  $n++
  $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
  $fail = @()
  # the smallest legitimate texture here is a 16x16 fully transparent crop stage at 95 bytes
  if ($bytes.Length -lt 60) { $fail += 'too small' }
  $magic = ($bytes[0..7] | ForEach-Object { $_.ToString('X2') }) -join ' '
  if ($magic -ne '89 50 4E 47 0D 0A 1A 0A') { $fail += ('bad magic ' + $magic) }
  # last 8 bytes of a valid PNG live inside the IEND chunk: 49 45 4E 44 AE 42 60 82
  $tail = ($bytes[($bytes.Length - 8)..($bytes.Length - 1)] | ForEach-Object { $_.ToString('X2') }) -join ' '
  if ($tail -ne '49 45 4E 44 AE 42 60 82') { $fail += ('bad IEND ' + $tail) }
  if ($fail.Count -gt 0) {
    $bad++
    Write-Output ('BAD PNG ' + $_.FullName.Substring($texDir.Length + 1) + '  :: ' + ($fail -join '; '))
  }
  if ($fail.Count -eq 0) {
    # IHDR: signature 0-7, chunk length 8-11, "IHDR" 12-15, width 16-19, height 20-23
    $w = [int]$bytes[16] * 16777216 + [int]$bytes[17] * 65536 + [int]$bytes[18] * 256 + [int]$bytes[19]
    $h = [int]$bytes[20] * 16777216 + [int]$bytes[21] * 65536 + [int]$bytes[22] * 256 + [int]$bytes[23]
    $key = ($w.ToString() + 'x' + $h)
    if ($sizes.ContainsKey($key)) { $sizes[$key]++ } else { $sizes[$key] = 1 }
  }
}
Write-Output ''
Write-Output ("png files checked : " + $n)
Write-Output ("corrupted         : " + $bad)
Write-Output 'dimension spread  :'
$sizes.Keys | Sort-Object | ForEach-Object { Write-Output ('  ' + $_ + ' : ' + $sizes[$_]) }
