$ErrorActionPreference = 'Stop'

# Pushes this repository to GitHub.
#
# The token is asked for at the prompt and is never written to disk, never put on the command line and never stored
# in .git/config. Two details make that true:
#
#   - Read-Host -AsSecureString keeps it off the screen and out of the console buffer, so it cannot end up in a
#     transcript or in a terminal's scrollback.
#   - git is handed the token through GIT_ASKPASS rather than through the remote URL. A token in a remote URL is
#     saved in .git/config in plain text and stays there for every later command; askpass is per-invocation only.
#
# After the push, revoke the token if it was created just for this: a token that has been pasted anywhere is a
# token that should not outlive the job it was made for.
#
# Pure ASCII script.

$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$askpass = $null
try {
    git remote get-url origin *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'There is no "origin" remote. Add one with: git remote add origin https://github.com/<user>/<repo>.git'
    }
    $remote = (git remote get-url origin).Trim()
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    Write-Host ""
    Write-Host ("remote : " + $remote)
    Write-Host ("branch : " + $branch)
    $pending = (git log --oneline ("origin/" + $branch + ".." + $branch) 2>$null | Measure-Object).Count
    Write-Host ("commits to push: " + $pending)
    Write-Host ""

    Write-Host "Paste your GitHub token at the prompt below. It will not be shown as you type."
    $secure = Read-Host -Prompt ("GitHub token for " + $remote) -AsSecureString

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $env:TFC_FOOD_PORT_GIT_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    if ([string]::IsNullOrWhiteSpace($env:TFC_FOOD_PORT_GIT_TOKEN)) {
        throw 'No token was entered, so there is nothing to authenticate with.'
    }

    # The askpass helper git runs when it needs a password. It reads the token from the environment, so the token
    # itself is never written to this file - only the name of the variable holding it. The prompt text arrives as
    # argument 1, which is how the username request is told apart from the password one.
    $askpass = Join-Path ([System.IO.Path]::GetTempPath()) ('tfc-food-port-askpass-' + [guid]::NewGuid().ToString('N') + '.cmd')
    $askpassLines = @(
        '@echo off'
        'echo %~1 | findstr /i "username" >nul'
        'if %errorlevel%==0 (echo x-access-token) else (echo %TFC_FOOD_PORT_GIT_TOKEN%)'
    )
    [System.IO.File]::WriteAllLines($askpass, $askpassLines, (New-Object System.Text.ASCIIEncoding))

    $env:GIT_ASKPASS = $askpass
    $env:GIT_TERMINAL_PROMPT = '0'

    Write-Host ""
    Write-Host ("pushing " + $branch + " to " + $remote + " ...")
    git push -u origin $branch
    if ($LASTEXITCODE -ne 0) {
        throw ('git push failed with exit code ' + $LASTEXITCODE + '. A 401 means the token is wrong or expired; a 403 means it lacks permission to write to this repository.')
    }

    Write-Host ""
    Write-Host "Pushed."
    Write-Host ""
    Write-Host "To cut a release, push a version tag - the GitHub Actions workflow builds the mod and attaches the"
    Write-Host "jar to the release for that tag:"
    Write-Host "    git tag v1.0.0"
    Write-Host "    git push origin v1.0.0"
}
finally {
    if ($askpass -and (Test-Path $askpass)) { Remove-Item $askpass -Force -ErrorAction SilentlyContinue }
    Remove-Item Env:\GIT_ASKPASS -ErrorAction SilentlyContinue
    Remove-Item Env:\GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
    Remove-Item Env:\TFC_FOOD_PORT_GIT_TOKEN -ErrorAction SilentlyContinue
    Pop-Location
}
