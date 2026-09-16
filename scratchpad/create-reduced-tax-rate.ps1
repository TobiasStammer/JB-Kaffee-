$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wc-lib.ps1" | Out-Null
$uri = (Get-WcBase) + '/taxes'
$body = @{ country='DE'; state=''; rate='7.0000'; name='VAT'; class='reduced-rate'; shipping=$false; priority=1 } | ConvertTo-Json
try {
  Invoke-RestMethod -Uri $uri -Method POST -Headers (Get-WcHeaders) -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body))
} catch {
  $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
  Write-Host "BODY:" $reader.ReadToEnd()
}
