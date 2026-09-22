$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. "$root\wp-lib.ps1" | Out-Null
$u=[char]0x00FC; $a=[char]0x00E4; $o=[char]0x00F6; $s=[char]0x00DF; $EUR=[char]0x20AC

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

function DateField($name,$label,$req,$help='') {
  [pscustomobject]@{
    attributes = [pscustomobject]@{ name=$name; class=''; value=''; date_format='d.m.Y'; placeholder='TT.MM.JJJJ' }
    element = 'input_date'
    settings = [pscustomobject]@{
      label=$label; help_message=$help
      conditional_logics=@()
      container_class=''; admin_field_label=$label; label_placement=''
      date_config=[pscustomobject]@{ date_range=$false; enable_time=$false; date_format='d.m.Y'; disable_type='disable_past_dates'; disable_dates=''; week_start='1' }
      validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte ausf'+$u+'llen'); value=$req } }
    }
    uniqElKey = "el_$name"
    editor_options = [pscustomobject]@{ title='Date / Time'; icon_class='ff-edit-date'; template='inputDate' }
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
$ort = TextField 'ort' 'Veranstaltungsort' 'Ort der Veranstaltung' $false

$datumVon = DateField 'datum_von' 'Datum von' $true
$datumBis = DateField 'datum_bis' 'Datum bis' $true

$getraenke = [pscustomobject]@{
  attributes=[pscustomobject]@{ type='checkbox'; name='getraenke'; value=@() }
  element='input_checkbox'
  settings=[pscustomobject]@{
    label=('Gew'+$u+'nschte Getr'+$a+'nke'); help_message='Mehrfachauswahl m'+$o+'glich'
    conditional_logics=@(); container_class=''; admin_field_label=('Getr'+$a+'nke'); label_placement=''
    advanced_options=@(
      [pscustomobject]@{ label='Kaffee & Espresso'; value='Kaffee & Espresso'; calc_value=''; image=''; id=1 }
      [pscustomobject]@{ label='Cappuccino'; value='Cappuccino'; calc_value=''; image=''; id=2 }
      [pscustomobject]@{ label='Latte Macchiato'; value='Latte Macchiato'; calc_value=''; image=''; id=3 }
    )
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte ausw'+$a+'hlen'); value=$false } }
  }
  uniqElKey='el_getraenke'; editor_options=[pscustomobject]@{ title='Check Box'; icon_class='ff-edit-checkbox'; template='inputCheckable' }
}

$milch = [pscustomobject]@{
  attributes=[pscustomobject]@{ type='radio'; name='milch'; value='' }
  element='input_radio'
  settings=[pscustomobject]@{
    container_class=''; label=('Milch gew'+$u+'nscht?'); admin_field_label='Milch'; label_placement=''; display_type=''
    help_message=('F'+$u+'r Cappuccino und Latte Macchiato wird ein Milchsystem ben'+$o+'tigt')
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte ausw'+$a+'hlen'); value=$true } }
    conditional_logics=@()
    advanced_options=@(
      [pscustomobject]@{ label=('Ja '+[char]0x2013+' mit Milchsystem'); value=('Ja '+[char]0x2013+' mit Milchsystem'); calc_value=''; image=''; id=1 }
      [pscustomobject]@{ label=('Nein '+[char]0x2013+' nur Kaffee & Espresso'); value=('Nein '+[char]0x2013+' nur Kaffee & Espresso'); calc_value=''; image=''; id=2 }
      [pscustomobject]@{ label=('Unsicher '+[char]0x2013+' bitte beraten'); value=('Unsicher '+[char]0x2013+' bitte beraten'); calc_value=''; image=''; id=3 }
    )
  }
  uniqElKey='el_milch'; editor_options=[pscustomobject]@{ title='Radio Field'; icon_class='ff-edit-radio'; element='input-radio'; template='inputRadio' }
}

$tassenanzahl = [pscustomobject]@{
  attributes=[pscustomobject]@{ name='tassenanzahl'; class=''; value=''; type='number'; placeholder='z. B. 50'; step='1'; min='1'; max='' }
  element='input_number'
  settings=[pscustomobject]@{
    label=('Gesch'+$a+'tzte Tassenanzahl'); help_message=('Ungef'+$a+'hre Anzahl Kaffeespezialit'+$a+'ten f'+$u+'r Ihre G'+$a+'ste')
    conditional_logics=@(); container_class=''; admin_field_label='Tassenanzahl'; label_placement=''
    validation_rules=[pscustomobject]@{
      required=[pscustomobject]@{ message=('Bitte ausf'+$u+'llen'); value=$true }
      numeric=[pscustomobject]@{ message=('Bitte eine Zahl eingeben'); value=$true }
    }
  }
  uniqElKey='el_tassenanzahl'; editor_options=[pscustomobject]@{ title='Number Field'; icon_class='ff-edit-number'; template='inputNumber' }
}

$tassenBenoetigt = [pscustomobject]@{
  attributes=[pscustomobject]@{ type='radio'; name='tassen_benoetigt'; value='' }
  element='input_radio'
  settings=[pscustomobject]@{
    container_class=''; label=('Werden Tassen/Becher ben'+$o+'tigt?'); admin_field_label='Tassen'; label_placement=''; display_type=''
    help_message=''
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte ausw'+$a+'hlen'); value=$true } }
    conditional_logics=@()
    advanced_options=@(
      [pscustomobject]@{ label=('Ja '+[char]0x2013+' bitte mitbringen'); value=('Ja '+[char]0x2013+' bitte mitbringen'); calc_value=''; image=''; id=1 }
      [pscustomobject]@{ label=('Nein '+[char]0x2013+' wir haben eigenes Geschirr'); value=('Nein '+[char]0x2013+' wir haben eigenes Geschirr'); calc_value=''; image=''; id=2 }
    )
  }
  uniqElKey='el_tassen_ben'; editor_options=[pscustomobject]@{ title='Radio Field'; icon_class='ff-edit-radio'; element='input-radio'; template='inputRadio' }
}

$nachricht = [pscustomobject]@{
  attributes=[pscustomobject]@{ value='';name='nachricht';id='';class='';placeholder=('Weitere W'+$u+'nsche, Anzahl G'+$a+'ste, R'+$u+'ckfragen ...') }
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
    advanced_options=@([pscustomobject]@{ label=('Meine Angaben werden zur Bearbeitung der Mietanfrage verwendet. '+[char]0x2013+' Details in der Datenschutzerkl'+$a+'rung.'); value='Ja' })
    validation_rules=[pscustomobject]@{ required=[pscustomobject]@{ message=('Bitte best'+$a+'tigen'); value=$true } }
  }
  uniqElKey='el_consent'; editor_options=[pscustomobject]@{ title='Check Box'; icon_class='ff-edit-checkbox'; template='inputCheckable' }
}

$allFields = @($name,$email,$tel,$ort,$datumVon,$datumBis,$getraenke,$milch,$tassenanzahl,$tassenBenoetigt,$nachricht,$consent)
$i=0; foreach ($fld in $allFields) { $fld | Add-Member -NotePropertyName index -NotePropertyValue $i -Force; $i++ }

$fieldsObj = [pscustomobject]@{
  fields = $allFields
  submitButton = [pscustomobject]@{
    uniqElKey='el_submit'
    settings=[pscustomobject]@{
      button_ui=[pscustomobject]@{ img_url=''; type='default'; text='Mietanfrage senden' }
      color='#ffffff'; button_size='md'; align='left'; container_class=''; background_color='#334155'; button_style='default'; help_message=''
    }
    attributes=[pscustomobject]@{ class=''; type='submit' }
    editor_options=[pscustomobject]@{ title='Submit Button' }
    element='button'
  }
}
$fieldsJson = $fieldsObj | ConvertTo-Json -Depth 25 -Compress

# Ziel: Form 4 (per Duplikat von Form 3 angelegt)
$fid = 4
$res = wp POST "/fluentform/v1/forms/$fid" @{ title=('Kaffeemaschine f'+$u+'r Events mieten'); formFields=$fieldsJson }
Write-Host ("Form $fid aktualisiert: $($res.title)")

# Kontrolle
$chk = (wp GET "/fluentform/v1/forms/$fid").form_fields | ConvertFrom-Json
$chk.fields | ForEach-Object { Write-Host ("  {0,-16} {1,-20} {2}" -f $_.element, $_.attributes.name, $_.settings.label) }
Write-Host "`nFORM_ID=$fid"
