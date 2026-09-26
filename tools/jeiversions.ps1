foreach ($a in @('jei-26.1.2-neoforge', 'jei-26.1.2-common-api')) {
  Write-Output ('=== ' + $a)
  $t = curl.exe -s -m 25 ("https://maven.blamejared.com/mezz/jei/" + $a + '/') 2>&1
  if ($t) {
    [regex]::Matches(($t -join ''), 'href="([^"]+)/"' ) | ForEach-Object { $_.Groups[1].Value } |
      Where-Object { $_ -match '^\d' } | Sort-Object -Unique | Select-Object -Last 10 | ForEach-Object { Write-Output ('   ' + $_) }
  } else { Write-Output '  (no listing)' }
}
