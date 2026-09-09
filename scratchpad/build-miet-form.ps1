$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null
$u=[char]0x00FC; $a=[char]0x00E4; $o=[char]0x00F6; $s=[char]0x00DF; $U=[char]0x00DC

function TextField($name,$label,$ph,$req,$help='') {
  [pscustomobject]@{
    attributes = [pscustomobject]@{ placeholder=$ph; class=''; name=$name; value=''; type='text' }
    element = 'input_text'
    settings = [pscustomobject]@{
      label=$label; help_message=$help
      conditional_logics=[pscustomobject]@{ conditions=@([pscustomobject]@{field='';operator='';value=''}); status=$false; type='any' }
      container_class=''; admin_field_label=$label; label_placement=''
      validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte ausf'+$u+'llen'); value=$req } }
    }
    uniqElKey = "el_$name"
    editor_options = [pscustomobject]@{ title='Simple Text'; icon_class='ff-edit-text'; template='inputText' }
  }
}

$name = TextField 'name' 'Name' 'Ihr Name' $true
$email = [pscustomobject]@{
  attributes=[pscustomobject]@{ value='';name='email';id='';class='';type='email';placeholder='ihre@e-mail.de' }
  element='input_email'
  settings=[pscustomobject]@{
    label='E-Mail'; help_message=''; conditional_logics=@(); container_class=''; admin_field_label=''; label_placement=''
    validation_rules=[pscustomobject]@{
      email=[pscustomobject]@{ message=('Bitte eine g'+$u+'ltige E-Mail-Adresse angeben'); value=$true }
      required=[pscustomobject]@{ message=('Bitte ausf'+$u+'llen'); value=$true }
    }
  }
  uniqElKey='el_email'; editor_options=[pscustomobject]@{ title='E-Mail'; icon_class='ff-edit-email'; template='inputText' }
}
$tel = TextField 'telefon' 'Telefon' ('f'+$u+'r schnelle R'+$u+'ckmeldung') $true

$geraet = [pscustomobject]@{
  attributes=[pscustomobject]@{ value='';name='mietgeraet';id='';class='';placeholder='Bitte w'+$a+'hlen';multiple=$false }
  element='select'
  settings=[pscustomobject]@{
    help_message=''; conditional_logics=@()
    advanced_options=@(
      [pscustomobject]@{ value='Jura E6 (40 Euro)'; label='Jura E6 - 40 '+[char]0x20AC }
      [pscustomobject]@{ value='Jura E8 (50 Euro)'; label='Jura E8 - 50 '+[char]0x20AC }
      [pscustomobject]@{ value='Jura X8 Gastro (100 Euro)'; label='Jura X8 (Gastro) - 100 '+[char]0x20AC }
      [pscustomobject]@{ value='egal / bitte beraten'; label='egal - bitte beraten' }
    )
    admin_field_label=('Gew'+$u+'nschtes Mietger'+$a+'t'); label=('Gew'+$u+'nschtes Mietger'+$a+'t')
    enable_select_2='no'; max_selection=''; container_class=''; label_placement=''
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte ausw'+$a+'hlen'); value=$true } }
  }
  uniqElKey='el_geraet'; editor_options=[pscustomobject]@{ title='Dropdown'; icon_class='ff-edit-dropdown'; template='select' }
}

$zeitraum = TextField 'zeitraum' 'Wunschzeitraum' 'z. B. ab KW 40 oder Anfang Oktober' $false ('Wann m'+$o+'chten Sie Ihr Ger'+$a+'t abgeben?')

$nachricht = [pscustomobject]@{
  attributes=[pscustomobject]@{ value='';name='nachricht';id='';class='';placeholder=('Ihre Kaffeemaschine, geplanter Reparaturgrund, R'+$u+'ckfragen ...') }
  element='textarea'
  settings=[pscustomobject]@{
    label='Nachricht (optional)'; help_message=''
    conditional_logics=[pscustomobject]@{ conditions=@([pscustomobject]@{field='';operator='';value=''}); status=$false; type='any' }
    container_class=''; admin_field_label='Nachricht'; label_placement=''; rows='3'; cols='2'
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=''; value=$false } }
  }
  uniqElKey='el_msg'; editor_options=[pscustomobject]@{ title='Text Area'; icon_class='ff-edit-textarea'; template='inputTextarea' }
}

$consent = [pscustomobject]@{
  attributes=[pscustomobject]@{ type='checkbox'; name='einwilligung'; value=@('Ja') }
  element='input_checkbox'
  settings=[pscustomobject]@{
    label='Einwilligung'; help_message=''
    conditional_logics=[pscustomobject]@{ conditions=@([pscustomobject]@{field='';operator='';value=''}); status=$false; type='any' }
    container_class=''; admin_field_label='Einwilligung'; label_placement=''
    advanced_options=@([pscustomobject]@{ label=('Meine Angaben werden zur Bearbeitung der Reservierung verwendet. '+[char]0x2013+' Details in der Datenschutzerkl'+$a+'rung.'); value='Ja' })
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte best'+$a+'tigen'); value=$true } }
  }
  uniqElKey='el_consent'; editor_options=[pscustomobject]@{ title='Check Box'; icon_class='ff-edit-checkbox'; template='inputCheckable' }
}

$i=0; foreach ($fld in @($name,$email,$tel,$geraet,$zeitraum,$nachricht,$consent)) { $fld | Add-Member -NotePropertyName index -NotePropertyValue $i -Force; $i++ }

$fieldsObj = [pscustomobject]@{
  fields = @($name,$email,$tel,$geraet,$zeitraum,$nachricht,$consent)
  submitButton = [pscustomobject]@{
    uniqElKey='el_submit'
    settings=[pscustomobject]@{
      button_ui=[pscustomobject]@{ img_url=''; type='default'; text='Reservierung anfragen' }
      color='#ffffff'; button_size='md'; align='left'; container_class=''; background_color='#334155'; button_style='default'; help_message=''
    }
    attributes=[pscustomobject]@{ class=''; type='submit' }
    editor_options=[pscustomobject]@{ title='Submit Button' }
    element='button'
  }
}
$fieldsJson = $fieldsObj | ConvertTo-Json -Depth 25 -Compress

# Ziel: Form 3 (per Duplikat von Form 2 angelegt)
$fid = 3
$res = wp POST "/fluentform/v1/forms/$fid" @{ title=('Mietger'+$a+'t reservieren'); formFields=$fieldsJson }
Write-Host ("Form $fid aktualisiert: $($res.title)")

# Kontrolle
$chk = (wp GET "/fluentform/v1/forms/$fid").form_fields | ConvertFrom-Json
$chk.fields | ForEach-Object { Write-Host ("  {0,-14} {1}" -f $_.attributes.name, $_.settings.label) }
Write-Host "`nFORM_ID=$fid"
