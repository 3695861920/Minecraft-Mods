Add-Type -AssemblyName System.IO.Compression.FileSystem
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$z = [System.IO.Compression.ZipFile]::OpenRead($jar)
$crops = @('barley','oat','rye','wheat','rice','maize','beet','cabbage','carrot','garlic','onion','potato',
           'green_bean','lentil','soybean','peanut','radish','cassava','squash','tomato',
           'red_bell_pepper','yellow_bell_pepper','pumpkin','melon','sugarcane')
$names = $z.Entries | ForEach-Object { $_.FullName }
foreach ($c in $crops) {
  $stages = @()
  for ($i = 0; $i -lt 12; $i++) {
    if ($names -contains ("assets/tfc/textures/block/crop/$c`_$i.png")) { $stages += $i }
  }
  $seed = ($names -contains "assets/tfc/textures/item/seeds/$c.png")
  $model7 = ($names -contains "assets/tfc/models/block/crop/$c`_age_7.json")
  Write-Output ("$c`tstages=" + ($stages -join ',') + "`tseedTex=$seed`tmodel7=$model7")
}
$z.Dispose()
