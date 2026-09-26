$urls = @(
  'https://maven.blamejared.com/mezz/jei/',
  'https://maven.blamejared.com/mezz/jei/jei-26.1.2-neoforge/',
  'https://maven.blamejared.com/mezz/jei/jei-26.1.2-common-api/',
  'https://maven.blamejared.com/mezz/jei/jei-26.1.2-neoforge-api/',
  'https://repo1.maven.org/maven2/mezz/jei/'
)
foreach ($u in $urls) {
  $r = curl.exe -s -o NUL -m 20 -w '%{http_code}' $u 2>&1
  Write-Output ("$r  <-  $u")
}
Write-Output ''
Write-Output '=== try the blamejared version API ==='
$j = curl.exe -s -m 25 'https://maven.blamejared.com/api/maven/versions/releases/mezz/jei/jei-26.1.2-neoforge' 2>&1
if ($j) { $j -join '' } else { Write-Output '  (no response)' }
