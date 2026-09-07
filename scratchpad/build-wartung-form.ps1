$ErrorActionPreference = 'Stop'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null
$u = [char]0x00FC; $a = [char]0x00E4; $o = [char]0x00F6

$src = wp GET '/fluentform/v1/forms/1'
$sf  = $src.form_fields | ConvertFrom-Json
$byName = @{}
foreach ($fld in $sf.fields) { if ($fld.attributes.name) { $byName[$fld.attributes.name] = $fld } }

$name = $byName['name']
$name.settings.label = 'Name'
$email = $byName['email']
$hers = $byName['hersteller']
$hers.settings.label = 'Kaffeemaschine'
$hers.settings.admin_field_label = 'Kaffeemaschine'
$hers.attributes.placeholder = "Marke w${a}hlen"

# neues Textfeld: letzte Wartung / Kaufdatum
$wart = [pscustomobject]@{
  attributes = [pscustomobject]@{ placeholder = 'z. B. 09/2024'; class = ''; name = 'letzte_wartung'; value = ''; type = 'text' }
  element = 'input_text'
  settings = [pscustomobject]@{
    label = "Letzte Wartung oder Kaufdatum (Monat/Jahr)"
    help_message = "Wenn unbekannt, bitte das ungef${a}hre Kaufjahr angeben."
    conditional_logics = [pscustomobject]@{ conditions = @([pscustomobject]@{ field=''; operator=''; value='' }); status = $false; type = 'any' }
    container_class = ''
    admin_field_label = 'Letzte Wartung'
    label_placement = ''
    validation_rules = [pscustomobject]@{ required = [pscustomobject]@{ message = 'Bitte ausf' + $u + 'llen'; value = $true } }
  }
  uniqElKey = 'el_wartung'
  editor_options = [pscustomobject]@{ title = 'Simple Text'; icon_class = 'ff-edit-text'; template = 'inputText' }
  index = 3
}

$consent = [pscustomobject]@{
  attributes = [pscustomobject]@{ type = 'checkbox'; name = 'einwilligung'; value = @('Ja, erinnert mich') }
  element = 'input_checkbox'
  settings = [pscustomobject]@{
    label = "Einwilligung"
    help_message = ''
    conditional_logics = [pscustomobject]@{ conditions = @([pscustomobject]@{ field=''; operator=''; value='' }); status = $false; type = 'any' }
    container_class = ''
    admin_field_label = 'Einwilligung'
    label_placement = ''
    advanced_options = @([pscustomobject]@{ label = "Ich m${o}chte per E-Mail an die n${a}chste Wartung erinnert werden. Die Daten werden nur daf${u}r genutzt und k${o}nnen jederzeit widerrufen werden."; value = 'Ja, erinnert mich' })
    validation_rules = [pscustomobject]@{ required = [pscustomobject]@{ message = 'Bitte best' + $a + 'tigen'; value = $true } }
  }
  uniqElKey = 'el_consent'
  editor_options = [pscustomobject]@{ title = 'Check Box'; icon_class = 'ff-edit-checkbox'; template = 'inputCheckable' }
  index = 4
}

$name.index = 0; $email.index = 1; $hers.index = 2

$fieldsObj = [pscustomobject]@{ fields = @($name, $email, $hers, $wart, $consent); submitButton = $sf.submitButton }
if ($fieldsObj.submitButton) {
  $fieldsObj.submitButton.settings.button_ui.text = 'Erinnerung aktivieren'
}
$fieldsJson = $fieldsObj | ConvertTo-Json -Depth 25 -Compress

$body = @{ title = 'Wartungserinnerung'; formFields = $fieldsJson }
$res = wp POST '/fluentform/v1/forms/2' $body
Write-Host ("Form 2 gespeichert: {0}" -f $res.title)

# Kontrolle
$chk = wp GET '/fluentform/v1/forms/2'
$cf = $chk.form_fields | ConvertFrom-Json
$cf.fields | ForEach-Object { Write-Host ("  {0,-16} {1}" -f $_.attributes.name, $_.settings.label) }
