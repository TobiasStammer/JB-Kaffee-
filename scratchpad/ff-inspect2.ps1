$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null

$src = wp GET '/fluentform/v1/forms/1'
$sf  = $src.form_fields | ConvertFrom-Json

foreach ($fld in $sf.fields) {
  $n = $fld.attributes.name
  Write-Host ("[{0}] name={1} label={2}" -f $fld.element, $n, $fld.settings.label)
  if ($fld.settings.advanced_options) {
    foreach ($o in $fld.settings.advanced_options) {
      Write-Host ("    - value='{0}' label='{1}'" -f $o.value, $o.label)
    }
  }
}
