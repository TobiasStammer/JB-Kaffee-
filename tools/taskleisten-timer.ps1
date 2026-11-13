# Taskleisten-Timer: Tray-Icon mit Restminuten. Linksklick = Timer-Menue, Rechtsklick = Menue.
# Start: taskleisten-timer.vbs (ohne Konsolenfenster). ASCII-only wegen PS 5.1.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:end = $null
$script:total = 0
$script:flash = $false

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Visible = $true

function Set-TimerIcon([string]$text, $bg) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush $bg
    $g.FillEllipse($brush, 0, 0, 31, 31)
    $size = 17; if ($text.Length -ge 3) { $size = 11 } elseif ($text.Length -eq 2) { $size = 14 }
    $font = New-Object System.Drawing.Font 'Segoe UI', $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString($text, $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 1, 32, 32), $sf)
    $h = $bmp.GetHicon()
    $old = $notify.Icon
    $notify.Icon = [System.Drawing.Icon]::FromHandle($h)
    $g.Dispose(); $bmp.Dispose(); $brush.Dispose(); $font.Dispose()
}

$blue = [System.Drawing.Color]::FromArgb(0, 120, 212)
$red = [System.Drawing.Color]::FromArgb(200, 40, 40)
$gray = [System.Drawing.Color]::FromArgb(90, 90, 90)

function Start-Countdown([double]$minutes) {
    $script:total = $minutes * 60
    $script:end = (Get-Date).AddMinutes($minutes)
    $script:flash = $false
    $timer.Start()
    Update-Display
}

function Stop-Countdown {
    $script:end = $null
    $timer.Stop()
    Set-TimerIcon '--' $gray
    $notify.Text = 'Timer: inaktiv'
}

function Update-Display {
    if ($null -eq $script:end) { return }
    $rest = [int][math]::Ceiling(($script:end - (Get-Date)).TotalSeconds)
    if ($rest -le 0) {
        $script:end = $null
        $script:flash = $true
        [System.Media.SystemSounds]::Exclamation.Play()
        $notify.BalloonTipTitle = 'Timer abgelaufen'
        $notify.BalloonTipText = 'Die Zeit ist um.'
        $notify.ShowBalloonTip(10000)
        $script:flashCount = 0
        return
    }
    $m = [math]::Floor($rest / 60); $s = $rest % 60
    if ($rest -gt 99 * 60) { $txt = "$m" }
    elseif ($rest -ge 60) { $txt = "$([math]::Ceiling($rest / 60))" }
    else { $txt = "$s" }
    $col = $blue; if ($rest -lt 60) { $col = $red }
    Set-TimerIcon $txt $col
    $notify.Text = ('Timer: {0}:{1:00} verbleibend' -f $m, $s)
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$script:flashCount = 0
$timer.Add_Tick({
    if ($script:flash) {
        $script:flashCount++
        $on = ($script:flashCount % 2 -eq 0)
        if ($on) { Set-TimerIcon '0' $red } else { Set-TimerIcon '!' ([System.Drawing.Color]::FromArgb(230, 140, 0)) }
        $notify.Text = 'Timer abgelaufen'
        if ($script:flashCount -ge 40) { $script:flash = $false; $timer.Stop(); Set-TimerIcon '--' $gray; $notify.Text = 'Timer: inaktiv' }
    } else { Update-Display }
})

function Ask-Minutes {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'Timer'; $f.Size = New-Object System.Drawing.Size 260, 130
    $f.FormBorderStyle = 'FixedDialog'; $f.StartPosition = 'CenterScreen'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.TopMost = $true
    $l = New-Object System.Windows.Forms.Label; $l.Text = 'Minuten:'; $l.Location = '12,18'; $l.AutoSize = $true
    $n = New-Object System.Windows.Forms.NumericUpDown; $n.Location = '80,14'; $n.Width = 80; $n.Minimum = 0; $n.Maximum = 600; $n.DecimalPlaces = 1; $n.Value = 10
    $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'Start'; $ok.Location = '80,50'; $ok.DialogResult = 'OK'
    $f.Controls.AddRange(@($l, $n, $ok)); $f.AcceptButton = $ok
    if ($f.ShowDialog() -eq 'OK' -and $n.Value -gt 0) { Start-Countdown ([double]$n.Value) }
    $f.Dispose()
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip
foreach ($m in 1, 3, 5, 10, 15, 25, 45, 60) {
    $mi = $menu.Items.Add("$m Minuten")
    $mi.Tag = $m
    $mi.Add_Click({ param($s, $e) Start-Countdown ([double]$s.Tag) })
}
$menu.Items.Add('-') | Out-Null
$menu.Items.Add('Eigene Zeit...').Add_Click({ Ask-Minutes })
$menu.Items.Add('Stopp').Add_Click({ Stop-Countdown })
$menu.Items.Add('-') | Out-Null
$menu.Items.Add('Beenden').Add_Click({ $notify.Visible = $false; $timer.Stop(); [System.Windows.Forms.Application]::Exit() })
$notify.ContextMenuStrip = $menu
$notify.Add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Ask-Minutes } })

Stop-Countdown
if ($args.Count -gt 0) { Start-Countdown ([double]$args[0]) }
[System.Windows.Forms.Application]::Run()
