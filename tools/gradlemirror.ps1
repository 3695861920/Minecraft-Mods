$urls = @(
  'https://mirrors.huaweicloud.com/gradle/gradle-9.2.1-bin.zip',
  'https://mirrors.cloud.tencent.com/gradle/gradle-9.2.1-bin.zip',
  'https://mirrors.aliyun.com/gradle/gradle-9.2.1-bin.zip',
  'https://mirrors.ustc.edu.cn/gradle/gradle-9.2.1-bin.zip',
  'https://downloads.gradle.org/distributions/gradle-9.2.1-bin.zip'
)
foreach ($u in $urls) {
  $r = curl.exe -s -o NUL -m 20 -w '%{http_code} %{size_download}' -r 0-1023 $u 2>&1
  Write-Output ("$r  <-  $u")
}
Write-Output ''
Write-Output '=== mirror listings ==='
foreach ($u in @('https://mirrors.huaweicloud.com/gradle/', 'https://mirrors.cloud.tencent.com/gradle/')) {
  Write-Output ("--- $u")
  $t = curl.exe -s -m 20 $u 2>&1
  if ($t) {
    [regex]::Matches(($t -join ''), 'gradle-9\.[0-9.]+-bin\.zip') | ForEach-Object { $_.Value } | Sort-Object -Unique | Select-Object -Last 8 | ForEach-Object { Write-Output ('    ' + $_) }
  } else { Write-Output '    (no listing)' }
}
