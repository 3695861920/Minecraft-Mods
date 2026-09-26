$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Waits for the release workflow to finish and then reports what it produced.
#
# There is no notification path for a remote CI run the way there is for a local process, so polling the API is the
# only way to answer "is it done yet". The loop is bounded: after the deadline it reports whatever it last saw
# rather than hanging, since a cold cache can legitimately take several minutes and a first run may also be slower.
# Pure ASCII.

$repo = '3695861920/Minecraft-Mods'
$headers = @{ 'User-Agent' = 'tfc-food-port-check'; 'Accept' = 'application/vnd.github+json' }
$deadline = (Get-Date).AddMinutes(9)
$last = ''

while ((Get-Date) -lt $deadline) {
    try {
        $runs = Invoke-RestMethod -Uri ("https://api.github.com/repos/" + $repo + "/actions/runs") -Headers $headers -TimeoutSec 30
    } catch {
        Write-Output ('run query failed: ' + $_.Exception.Message)
        Start-Sleep -Seconds 20
        continue
    }
    if ($runs.total_count -eq 0) { Write-Output 'no runs'; break }

    $run = $runs.workflow_runs[0]
    $line = $run.name + ' #' + $run.run_number + '  status=' + $run.status + '  conclusion=' + $run.conclusion
    if ($line -ne $last) {
        Write-Output ((Get-Date).ToString('HH:mm:ss') + '  ' + $line)
        $last = $line
    }

    if ($run.status -eq 'completed') { break }
    Start-Sleep -Seconds 20
}

Write-Output ''
Write-Output '=== releases ==='
try {
    $rels = Invoke-RestMethod -Uri ("https://api.github.com/repos/" + $repo + "/releases") -Headers $headers -TimeoutSec 30
    if ($rels.Count -eq 0) {
        Write-Output 'no release published yet'
    } else {
        foreach ($rel in $rels) {
            Write-Output ('tag=' + $rel.tag_name + '  name=' + $rel.name + '  draft=' + $rel.draft + '  published=' + $rel.published_at)
            if ($rel.assets.Count -eq 0) {
                Write-Output '   (no assets)'
            } else {
                foreach ($a in $rel.assets) {
                    Write-Output ('   asset: ' + $a.name + '   ' + [Math]::Round($a.size / 1KB) + ' KB')
                }
            }
        }
    }
} catch {
    Write-Output ('release query failed: ' + $_.Exception.Message)
}
