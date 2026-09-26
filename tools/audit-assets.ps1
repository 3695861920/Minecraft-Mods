$root = Split-Path (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName -Parent
$assets = Join-Path $root 'src\main\resources\assets\tfc_food_port'

Write-Output '=== blockstates tree ==='
Get-ChildItem (Join-Path $assets 'blockstates') -Recurse -File | ForEach-Object {
  $_.FullName.Substring((Join-Path $assets 'blockstates').Length + 1) -replace '\\', '/'
} | Group-Object { ($_ -split '/')[0] } | ForEach-Object {
  Write-Output ('  ' + $_.Name + ' : ' + $_.Count)
}
Write-Output ('  TOTAL: ' + (Get-ChildItem (Join-Path $assets 'blockstates') -Recurse -File).Count)

Write-Output ''
Write-Output '=== model tree ==='
Get-ChildItem (Join-Path $assets 'models') -Recurse -File | ForEach-Object {
  $_.FullName.Substring((Join-Path $assets 'models').Length + 1) -replace '\\', '/'
} | Group-Object { ($_ -split '/')[0] + '/' + ($_ -split '/')[1] } | ForEach-Object {
  Write-Output ('  ' + $_.Name + ' : ' + $_.Count)
}

Write-Output ''
Write-Output '=== definitions tree ==='
Get-ChildItem (Join-Path $assets 'items') -Recurse -File | ForEach-Object {
  $_.FullName.Substring((Join-Path $assets 'items').Length + 1) -replace '\\', '/'
} | Group-Object { ($_ -split '/')[0] } | ForEach-Object {
  Write-Output ('  ' + $_.Name + ' : ' + $_.Count)
}
Write-Output ('  TOTAL: ' + (Get-ChildItem (Join-Path $assets 'items') -Recurse -File).Count)

Write-Output ''
Write-Output '=== texture tree ==='
Get-ChildItem (Join-Path $assets 'textures') -Recurse -File | ForEach-Object {
  $_.FullName.Substring((Join-Path $assets 'textures').Length + 1) -replace '\\', '/'
} | Group-Object { ($_ -split '/')[0] + '/' + ($_ -split '/')[1] } | ForEach-Object {
  Write-Output ('  ' + $_.Name + ' : ' + $_.Count)
}
