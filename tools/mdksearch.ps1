Write-Output '=== MDK mirror candidates ==='
$cands = @(
  'NeoForgeMDKs/MDK-26.1.2-ModDevGradle',
  'NeoForgeMDKs/MDK-26.1.2-NeoGradle',
  'NeoForgeMDKs/MDK-26.1.2-mdg',
  'NeoForgeMDKs/MDK-26.1.2-legacy',
  'neoforged/MDK'
)
foreach ($c in $cands) {
  foreach ($b in @('main', 'master', '26.1.x')) {
    $u = "https://codeload.github.com/$c/zip/refs/heads/$b"
    $r = curl.exe -s -o NUL -m 20 -w '%{http_code}' $u 2>&1
    if ($r -eq '200') { Write-Output ("OK   $c  branch=$b") }
  }
}

Write-Output ''
Write-Output '=== moddev-gradle versions ==='
$json = curl.exe -s -m 30 'https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/moddev-gradle' 2>&1
if ($json) {
  $vers = [regex]::Matches(($json -join ''), '"([0-9][^"]*)"') | ForEach-Object { $_.Groups[1].Value }
  $vers | Select-Object -Last 12 | ForEach-Object { Write-Output ('  ' + $_) }
} else { Write-Output '  (no response)' }
