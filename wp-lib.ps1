# wp-lib.ps1 - Helper für die WordPress REST API von new.kaffeetechniker.de
# Verwendung:  . .\wp-lib.ps1   (dot-source), danach z. B.:
#   wp GET  /wp/v2/posts?per_page=5
#   wp POST /wp/v2/posts @{ title='Titel'; status='draft'; content='<p>Hallo</p>' }
#   wp DELETE /wp/v2/posts/123?force=true
#
# Zugangsdaten kommen aus kaffeetechniker-integration.env und werden NICHT ausgegeben.

$script:KtEnvPath = Join-Path $PSScriptRoot 'kaffeetechniker-integration.env'

function Import-KtEnv {
    $map = @{}
    Get-Content $script:KtEnvPath | ForEach-Object {
        if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $map[$matches[1].Trim()] = $matches[2].Trim() }
    }
    $map
}

function Get-KtWpHeaders {
    $e    = Import-KtEnv
    $user = $e['WP_APP_USER']
    $pass = $e['WP_APP_PASSWORD'] -replace ' ', ''
    $b64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$user`:$pass"))
    @{ Authorization = "Basic $b64" }
}

function Get-KtWpBaseUrl {
    (Import-KtEnv)['WP_URL'].TrimEnd('/') + '/wp-json'
}

function wp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','PATCH','DELETE')]$Method,
        [Parameter(Mandatory)][string]$Path,          # z. B. /wp/v2/posts?per_page=5
        [Parameter()]$Body                            # Hashtable oder JSON-String (nur POST/PUT/PATCH)
    )
    $uri = (Get-KtWpBaseUrl) + '/' + $Path.TrimStart('/')
    $headers = Get-KtWpHeaders
    $params = @{ Uri = $uri; Method = $Method; Headers = $headers; ErrorAction = 'Stop' }

    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 20 }
        $params.Body        = [Text.Encoding]::UTF8.GetBytes($json)
        $params.ContentType = 'application/json; charset=utf-8'
    }

    try {
        Invoke-RestMethod @params
    } catch {
        $code = try { [int]$_.Exception.Response.StatusCode } catch { '?' }
        Write-Error "HTTP $code bei $Method $Path`n$($_.ErrorDetails.Message)"
    }
}

function Test-KtWpConnection {
    $me = wp GET /wp/v2/users/me
    if ($me.slug) {
        Write-Host "OK - verbunden als '$($me.name)' (slug: $($me.slug), id: $($me.id))" -ForegroundColor Green
    } else {
        Write-Host "Verbindung fehlgeschlagen" -ForegroundColor Red
    }
}

Write-Host "wp-lib geladen. Befehle: wp <Method> <Path> [Body], Test-KtWpConnection" -ForegroundColor Cyan
