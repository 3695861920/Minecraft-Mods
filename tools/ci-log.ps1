$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Downloads the failed job's log and prints the part around the error.
#
# The logs endpoint answers with a redirect to a signed URL holding a zip, so this follows the redirect, saves the
# zip, expands it and prints the lines around whatever gradle called a failure - the whole log is thousands of lines
# of dependency resolution and none of it is useful except the error and the few lines after it.
# Pure ASCII.

$repo = '3695861920/Minecraft-Mods'
$headers = @{ 'User-Agent' = 'tfc-food-port-check'; 'Accept' = 'application/vnd.github+json' }
$runId = 36253556368
$work = Join-Path $PSScriptRoot 'out\ci-logs'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$jobs = Invoke-RestMethod -Uri ("https://api.github.com/repos/" + $repo + "/actions/runs/" + $runId + "/jobs") -Headers $headers -TimeoutSec 30
$job = $jobs.jobs | Where-Object { $_.conclusion -eq 'failure' } | Select-Object -First 1
if (-not $job) { throw 'no failed job found' }
Write-Output ('failed job: ' + $job.name + '  id=' + $job.id)

$zip = Join-Path $work 'logs.zip'
Invoke-WebRequest -Uri ("https://api.github.com/repos/" + $repo + "/actions/jobs/" + $job.id + "/logs") -Headers $headers -OutFile $zip -TimeoutSec 120
Write-Output ('log zip: ' + [Math]::Round((Get-Item $zip).Length / 1KB) + ' KB')

$expand = Join-Path $work 'expanded'
if (Test-Path $expand) { Remove-Item $expand -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $expand -Force
$logFile = Get-ChildItem $expand -Recurse -File | Sort-Object Length -Descending | Select-Object -First 1
Write-Output ('log file: ' + $logFile.Name + '  ' + [Math]::Round($logFile.Length / 1KB) + ' KB')

$lines = Get-Content $logFile.FullName
Write-Output ''
Write-Output '=== lines matching a failure keyword (first 60) ==='
$idx = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'FAILURE|error:|Error:|What went wrong|Caused by|Execution failed|Could not|Cannot|not found|BUILD FAILED|Exception') { $idx += $i }
}
if ($idx.Count -eq 0) {
    Write-Output 'no obvious error keyword; printing the tail instead'
    $lines | Select-Object -Last 60
} else {
    $printed = 0
    foreach ($i in $idx) {
        if ($printed -ge 60) { break }
        Write-Output ('--- line ' + ($i + 1) + ' ---')
        for ($j = $i; $j -lt [Math]::Min($i + 6, $lines.Count); $j++) { Write-Output $lines[$j] }
        $printed++
    }
}
