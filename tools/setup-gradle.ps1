$ErrorActionPreference = 'Stop'
$wd = 'C:\Users\36958\Documents\AI\group'
# resolve workspace root from the TFC jar location (script must stay ASCII)
$jar = (Get-ChildItem 'C:\Users\36958\Documents\AI\*\*TerraFirmaCraft*.jar' -File | Select-Object -First 1).FullName
$wd = Split-Path $jar -Parent
$mdk = Join-Path $wd 'tools\mdk-src\MDK-26.1.2-ModDevGradle-main'

# --- gradle wrapper + build scripts ---
Copy-Item (Join-Path $mdk 'gradlew') $wd -Force
Copy-Item (Join-Path $mdk 'gradlew.bat') $wd -Force
Copy-Item (Join-Path $mdk 'build.gradle') $wd -Force
Copy-Item (Join-Path $mdk 'settings.gradle') $wd -Force
Copy-Item (Join-Path $mdk '.gitignore') $wd -Force
Copy-Item (Join-Path $mdk '.gitattributes') $wd -Force
New-Item -ItemType Directory -Force -Path (Join-Path $wd 'gradle\wrapper') | Out-Null
Copy-Item (Join-Path $mdk 'gradle\wrapper\gradle-wrapper.jar') (Join-Path $wd 'gradle\wrapper') -Force
Copy-Item (Join-Path $mdk 'gradle\wrapper\gradle-wrapper.properties') (Join-Path $wd 'gradle\wrapper') -Force

# --- mods.toml moves into the MDK's template directory so ${} expansion applies ---
New-Item -ItemType Directory -Force -Path (Join-Path $wd 'src\main\templates\META-INF') | Out-Null
$oldToml = Join-Path $wd 'src\main\resources\META-INF\neoforge.mods.toml'
if (Test-Path $oldToml) {
  Remove-Item $oldToml -Force
  Write-Output 'removed the literal mods.toml (now generated from the template)'
}
$tomlDir = Join-Path $wd 'src\main\resources\META-INF'
if ((Get-ChildItem $tomlDir -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item $tomlDir -Force }

Write-Output 'copied:'
Get-ChildItem $wd -File | ForEach-Object { Write-Output ('  ' + $_.Name) }
Get-ChildItem (Join-Path $wd 'gradle\wrapper') -File | ForEach-Object { Write-Output ('  gradle/wrapper/' + $_.Name) }
