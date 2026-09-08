$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null

# --- Form 1 (Kontaktformular): "Anderer Hersteller" ans Ende der Hersteller-Liste ---
$src = wp GET '/fluentform/v1/forms/1'
$sf  = $src.form_fields | ConvertFrom-Json

$hers = $sf.fields | Where-Object { $_.attributes.name -eq 'hersteller' }
if (-not $hers) { throw "Feld 'hersteller' nicht gefunden" }

$opts = @($hers.settings.advanced_options)
if ($opts.value -notcontains 'Anderer Hersteller') {
  $opts += [pscustomobject]@{ label = 'Anderer Hersteller'; value = 'Anderer Hersteller'; calc_value = '' }
  $hers.settings.advanced_options = $opts
}

$fieldsJson = $sf | ConvertTo-Json -Depth 25 -Compress
$res = wp POST '/fluentform/v1/forms/1' @{ title = $src.title; formFields = $fieldsJson }
Write-Host ("Form 1 gespeichert: {0}" -f $res.title)

# Kontrolle
$chk = (wp GET '/fluentform/v1/forms/1').form_fields | ConvertFrom-Json
$cf  = $chk.fields | Where-Object { $_.attributes.name -eq 'hersteller' }
$cf.settings.advanced_options | ForEach-Object { Write-Host ("  - {0}" -f $_.value) }
