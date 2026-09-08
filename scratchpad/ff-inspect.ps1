$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null

$form = wp GET '/fluentform/v1/forms/1'
$fields = $form.formFields
if ($fields -is [string]) { $fields = $fields | ConvertFrom-Json }

function Walk($nodes, $depth) {
  foreach ($n in $nodes) {
    $el = $n.element
    $name = $n.attributes.name
    $label = $n.settings.label
    Write-Host ((' ' * $depth) + "[$el] name=$name label=$label")
    if ($n.settings.advanced_options) {
      foreach ($o in $n.settings.advanced_options) {
        Write-Host ((' ' * ($depth+2)) + "opt: value='$($o.value)' label='$($o.label)'")
      }
    }
    if ($n.options) {
      # some builds use .options hashtable
      Write-Host ((' ' * ($depth+2)) + "options: " + ($n.options | ConvertTo-Json -Compress))
    }
    if ($n.columns) { foreach ($c in $n.columns) { Walk $c.fields ($depth+2) } }
    if ($n.fields)  { Walk $n.fields ($depth+2) }
  }
}
Walk $fields.fields 0

Write-Host "`n--- RAW Hersteller-Feld ---"
$json = $form.formFields
if ($json -isnot [string]) { $json = $json | ConvertTo-Json -Depth 20 }
$idx = $json.IndexOf('ersteller')
if ($idx -ge 0) { Write-Host $json.Substring([Math]::Max(0,$idx-1200), 2600) }
