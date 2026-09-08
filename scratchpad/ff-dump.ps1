$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null

$form = wp GET '/fluentform/v1/forms/1'
Write-Host "TOP KEYS:"
$form.PSObject.Properties.Name | ForEach-Object { Write-Host "  $_  ($($form.$_.GetType().Name))" }

$out = "$PSScriptRoot\ff1-full.json"
$form | ConvertTo-Json -Depth 40 | Set-Content -Encoding utf8 $out
Write-Host "geschrieben: $out"
