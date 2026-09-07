$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$sp='C:\Homepage\Neue Seite 2026\scratchpad'
$src=[System.Drawing.Bitmap]::FromFile("$sp\ladenfront-src.jpg")
$W=$src.Width;$H=$src.Height
$sc=0.5
$bw=[int]($W*$sc);$bh=[int]($H*$sc)
$b=New-Object System.Drawing.Bitmap($bw,$bh)
$g=[System.Drawing.Graphics]::FromImage($b)
$g.DrawImage($src,0,0,$bw,$bh)
$penMinor=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,255,0,0),1)
$penMajor=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200,0,255,0),1)
$font=New-Object System.Drawing.Font('Arial',9)
$brush=[System.Drawing.Brushes]::Yellow
for($x=0;$x -lt $W;$x+=100){
  $sx=[int]($x*$sc)
  $p= if($x%500 -eq 0){$penMajor}else{$penMinor}
  $g.DrawLine($p,$sx,0,$sx,$bh)
  if($x%200 -eq 0){ $g.DrawString("$x",$font,$brush,$sx+1,2) }
}
for($y=0;$y -lt $H;$y+=100){
  $sy=[int]($y*$sc)
  $p= if($y%500 -eq 0){$penMajor}else{$penMinor}
  $g.DrawLine($p,0,$sy,$bw,$sy)
  if($y%200 -eq 0){ $g.DrawString("$y",$font,$brush,2,$sy+1) }
}
$g.Dispose();$src.Dispose()
$b.Save("$sp\grid.png",[System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "grid.png $bw x $bh (Faktor $sc)"
