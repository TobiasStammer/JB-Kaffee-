# ssh-lib.ps1 - SSH/SFTP-Helper für den IONOS-Webspace (Passwort-Auth ohne Terminal-Prompt)
# Verwendung:  . .\ssh-lib.ps1   danach z. B.:
#   kt-ssh "ls -la ~"
#   kt-sftp-get "wp-content/themes/xyz/functions.php" ".\functions.php"
#   kt-sftp-put ".\functions.php" "wp-content/themes/xyz/functions.php"
#
# Nutzt SSH_ASKPASS, damit das Passwort aus der .env nicht interaktiv abgefragt wird.
# WICHTIG: Der SSH-Account aus der .env sieht die WordPress-Dateien dieser Site derzeit
# NICHT (leerer Webspace). Siehe SETUP-NOTIZEN.md.

$script:KtEnvPath  = Join-Path $PSScriptRoot 'kaffeetechniker-integration.env'
$script:KtAskpass  = Join-Path $env:TEMP 'kt-askpass.cmd'

function Import-KtEnv {
    $map = @{}
    Get-Content $script:KtEnvPath | ForEach-Object {
        if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $map[$matches[1].Trim()] = $matches[2].Trim() }
    }
    $map
}

function Initialize-KtAskpass {
    if (-not (Test-Path $script:KtAskpass)) {
        Set-Content -Path $script:KtAskpass -Value "@echo off`r`necho %KT_SSH_PW%" -Encoding ascii
    }
    $e = Import-KtEnv
    $env:KT_SSH_PW            = $e['IONOS_PASSWORD']
    $env:SSH_ASKPASS         = $script:KtAskpass
    $env:SSH_ASKPASS_REQUIRE = 'force'
}

function Get-KtSshTarget {
    $e = Import-KtEnv
    [pscustomobject]@{ User = $e['IONOS_USER']; Host = $e['IONOS_HOST']; Port = $e['IONOS_PORT'] }
}

function kt-ssh {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Command)
    Initialize-KtAskpass
    $t = Get-KtSshTarget
    ssh -p $t.Port -o StrictHostKeyChecking=accept-new -o NumberOfPasswordPrompts=1 "$($t.User)@$($t.Host)" ($Command -join ' ')
}

function kt-sftp-get {
    param([Parameter(Mandatory)][string]$RemotePath, [Parameter(Mandatory)][string]$LocalPath)
    Initialize-KtAskpass
    $t = Get-KtSshTarget
    "get `"$RemotePath`" `"$LocalPath`"" | sftp -P $t.Port -o StrictHostKeyChecking=accept-new -b - "$($t.User)@$($t.Host)"
}

function kt-sftp-put {
    param([Parameter(Mandatory)][string]$LocalPath, [Parameter(Mandatory)][string]$RemotePath)
    Initialize-KtAskpass
    $t = Get-KtSshTarget
    "put `"$LocalPath`" `"$RemotePath`"" | sftp -P $t.Port -o StrictHostKeyChecking=accept-new -b - "$($t.User)@$($t.Host)"
}

Write-Host "ssh-lib geladen. Befehle: kt-ssh, kt-sftp-get, kt-sftp-put" -ForegroundColor Cyan
