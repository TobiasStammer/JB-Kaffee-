# wc-lib.ps1 - Helper fuer die WooCommerce REST API (v3) von new.kaffeetechniker.de
# Schluessel (WC_CK / WC_CS) kommen aus kaffeetechniker-integration.env - NICHT ausgeben.
#   . .\wc-lib.ps1
#   wc GET  products?per_page=5
#   wc POST products @{ name='...'; type='simple'; regular_price='9.90' }

if (-not (Get-Command Import-KtEnv -ErrorAction SilentlyContinue)) { . "$PSScriptRoot\wp-lib.ps1" | Out-Null }

function Get-WcBase { (Import-KtEnv)['WP_URL'].TrimEnd('/') + '/wp-json/wc/v3' }
function Get-WcHeaders {
  $e = Import-KtEnv
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($e['WC_CK']):$($e['WC_CS'])"))
  @{ Authorization = "Basic $b64" }
}

function wc {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')]$Method,
    [Parameter(Mandatory)][string]$Path,
    [Parameter()]$Body
  )
  $params = @{
    Uri         = (Get-WcBase) + '/' + $Path.TrimStart('/')
    Method      = $Method
    Headers     = Get-WcHeaders
    ErrorAction = 'Stop'
  }
  if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
    $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 20 }
    $params.Body        = [Text.Encoding]::UTF8.GetBytes($json)
    $params.ContentType = 'application/json; charset=utf-8'
  }
  try { Invoke-RestMethod @params }
  catch {
    $code = try { [int]$_.Exception.Response.StatusCode } catch { '?' }
    Write-Error "WC HTTP $code bei $Method $Path`n$($_.ErrorDetails.Message)"
  }
}

Write-Host "wc-lib geladen. Befehle: wc <Method> <Path> [Body]" -ForegroundColor Cyan
