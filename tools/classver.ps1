Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($pat in @('*FarmersDelight*.jar', '*kaleidoscope*.jar')) {
  $jar = (Get-ChildItem ('C:\Users\36958\Documents\AI\*\' + $pat) -File | Select-Object -First 1).FullName
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  $e = $z.Entries | Where-Object { $_.FullName -like '*.class' } | Select-Object -First 1
  $s = $e.Open()
  $b = New-Object byte[] 8
  [void]$s.Read($b, 0, 8)
  $s.Close()
  $z.Dispose()
  # class file bytes 6..7 = major version
  $major = ($b[6] -shl 8) -bor $b[7]
  Write-Output ((Split-Path $jar -Leaf) + '  class major=' + $major)
}
