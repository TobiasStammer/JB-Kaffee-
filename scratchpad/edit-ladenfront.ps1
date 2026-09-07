$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sp = 'C:\Homepage\Neue Seite 2026\scratchpad'
$src = [System.Drawing.Bitmap]::FromFile("$sp\ladenfront-src.jpg")

function AvgColorSrc($bmp,$x,$y,$r){
  $rs=0;$gs=0;$bs=0;$n=0
  for($j=-$r;$j -le $r;$j++){ for($i=-$r;$i -le $r;$i++){
    $xx=[Math]::Min([Math]::Max($x+$i,0),$bmp.Width-1); $yy=[Math]::Min([Math]::Max($y+$j,0),$bmp.Height-1)
    $px=$bmp.GetPixel($xx,$yy); $rs+=$px.R;$gs+=$px.G;$bs+=$px.B;$n++ }}
  ,@([int]($rs/$n),[int]($gs/$n),[int]($bs/$n))
}
$skyTop = AvgColorSrc $src 470 130 6
$skyBot = AvgColorSrc $src 260 430 5
Write-Host ("Himmel oben ({0},{1},{2}) / unten ({3},{4},{5})" -f $skyTop[0],$skyTop[1],$skyTop[2],$skyBot[0],$skyBot[1],$skyBot[2])

# ---- 1) Zuschnitt (Original 2048x1365) ----
$cx=228; $cy=428; $cw=1612; $ch=884
$crop = New-Object System.Drawing.Bitmap($cw,$ch)
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.InterpolationMode='HighQualityBicubic'; $g.PixelOffsetMode='HighQuality'
$g.DrawImage($src,(New-Object System.Drawing.Rectangle(0,0,$cw,$ch)),$cx,$cy,$cw,$ch,[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose(); $src.Dispose()

# ---- 2) Himmel ueber der Dachkante fuellen (folgt dem Grat, Gradient nach ABSOLUTER Hoehe) ----
$pts = @(
  @(0,150),@(200,120),@(430,96),@(660,88),@(880,86),@(1070,92),@(1270,116),@(1450,150),@(1612,168)
)
function EdgeAt($x){
  for($k=0;$k -lt $pts.Count-1;$k++){
    if($x -ge $pts[$k][0] -and $x -le $pts[$k+1][0]){
      $f = ($x-$pts[$k][0])/[double]($pts[$k+1][0]-$pts[$k][0])
      return $pts[$k][1] + ($pts[$k+1][1]-$pts[$k][1])*$f
    }
  }
  return $pts[-1][1]
}
$gradRef = 175.0
for($x=0; $x -lt $cw; $x++){
  $fillTo=[int][Math]::Round((EdgeAt $x))
  for($y=0;$y -lt $fillTo;$y++){
    $t=[Math]::Min($y/$gradRef,1)
    $rr=[int]($skyTop[0]+($skyBot[0]-$skyTop[0])*$t)
    $gg=[int]($skyTop[1]+($skyBot[1]-$skyTop[1])*$t)
    $bb=[int]($skyTop[2]+($skyBot[2]-$skyTop[2])*$t)
    $d=$fillTo-$y
    if($d -le 2){
      $op=$crop.GetPixel($x,$y); $a=$d/3.0
      $rr=[int]($rr*$a+$op.R*(1-$a));$gg=[int]($gg*$a+$op.G*(1-$a));$bb=[int]($bb*$a+$op.B*(1-$a))
    }
    $crop.SetPixel($x,$y,[System.Drawing.Color]::FromArgb([Math]::Min($rr,255),[Math]::Min($gg,255),[Math]::Min($bb,255)))
  }
}
# Rest-Dachziegel / Entlueftung oben abdecken: sauberen Himmel seitlich herueberkopieren
foreach($reg in @(@(422,512,42,120),@(772,832,42,116))){
  $x1=$reg[0];$x2=$reg[1];$y1=$reg[2];$y2=$reg[3]
  for($y=$y1;$y -lt $y2;$y++){ for($x=$x1;$x -lt $x2;$x++){ $crop.SetPixel($x,$y,$crop.GetPixel($x-160,$y)) } }
}

# ---- 2b) weisse Corona-/Hinweisschilder auf der Tuer wegkopieren (vertikal, kurzer Versatz) ----
# @(x1,y1,x2,y2, dx,dy) - Quelle direkt darunter/darueber im selben Glas
$patches = @(
  @(291,489,349,529, 0, 96),   # dunkler Zettel oben auf der Tuer -> Glas darunter
  @(266,530,341,592, 0, 78),   # "BITTE EINZELN EINTRETEN" + Figuren -> Glas darunter
  @(302,581,336,607, 0, 40),   # roter "119"-Aufkleber
  @(390,556,431,628, 0,-74)    # Abstands-Piktogramm rechtes Seitenteil -> Glas darueber
)
foreach($pt in $patches){
  $x1=$pt[0];$y1=$pt[1];$x2=$pt[2];$y2=$pt[3];$dx=$pt[4];$dy=$pt[5]
  # zeilenweise kopieren + an den Raendern 2px ueberblenden
  for($y=$y1;$y -lt $y2;$y++){ for($x=$x1;$x -lt $x2;$x++){
    $sx=[Math]::Min([Math]::Max($x+$dx,0),$cw-1); $sy=[Math]::Min([Math]::Max($y+$dy,0),$ch-1)
    $src2=$crop.GetPixel($sx,$sy)
    $ex=[Math]::Min($x-$x1,$x2-1-$x); $ey=[Math]::Min($y-$y1,$y2-1-$y)
    $e=[Math]::Min($ex,$ey)
    if($e -lt 2){ $o=$crop.GetPixel($x,$y); $a=($e+1)/3.0
      $src2=[System.Drawing.Color]::FromArgb([int]($src2.R*$a+$o.R*(1-$a)),[int]($src2.G*$a+$o.G*(1-$a)),[int]($src2.B*$a+$o.B*(1-$a))) }
    $crop.SetPixel($x,$y,$src2)
  }}
}

# ---- 3) Ton / Farbe / Schaerfe / dezente Vignette ----
Add-Type -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class GradeF {
  public static void Run(Bitmap b){
    int w=b.Width,h=b.Height;
    var bd=b.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadWrite,PixelFormat.Format24bppRgb);
    int stride=bd.Stride,bytes=stride*h; byte[] buf=new byte[bytes]; Marshal.Copy(bd.Scan0,buf,0,bytes);
    byte[] lr=new byte[256],lg=new byte[256],lb=new byte[256];
    for(int i=0;i<256;i++){ double v=i/255.0;
      double x=Math.Pow(v,0.82); if(v<0.58) x+=(0.58-v)*0.17; x*=1.04; x+=(x-0.5)*0.045;
      if(x<0)x=0; if(x>1)x=1;
      lr[i]=C(x*1.010+0.002); lg[i]=C(x*1.001); lb[i]=C(x*0.990);
    }
    double cx=w/2.0,cy=h/2.0,maxd=Math.Sqrt(cx*cx+cy*cy);
    for(int y=0;y<h;y++){ int row=y*stride; double dy=(y-cy)/maxd;
      for(int x=0;x<w;x++){ int p=row+x*3;
        int B=lb[buf[p]],G=lg[buf[p+1]],R=lr[buf[p+2]];
        double gray=0.299*R+0.587*G+0.114*B,s=1.07;
        R=(int)(gray+(R-gray)*s);G=(int)(gray+(G-gray)*s);B=(int)(gray+(B-gray)*s);
        double dx=(x-cx)/maxd,d=Math.Sqrt(dx*dx+dy*dy);
        double vig=1.0-0.045*Math.Pow(Math.Max(0,(d-0.6)/0.4),2);
        buf[p]=Ci((int)(B*vig));buf[p+1]=Ci((int)(G*vig));buf[p+2]=Ci((int)(R*vig));
      }}
    byte[] o=(byte[])buf.Clone(); double amt=0.34; int[] k={1,2,1,2,4,2,1,2,1};
    for(int y=1;y<h-1;y++) for(int x=1;x<w-1;x++) for(int c=0;c<3;c++){
      int acc=0,idx=0; for(int j=-1;j<=1;j++) for(int i=-1;i<=1;i++) acc+=buf[(y+j)*stride+(x+i)*3+c]*k[idx++];
      int blur=acc/16,orig=buf[y*stride+x*3+c];
      o[y*stride+x*3+c]=Ci((int)(orig+(orig-blur)*amt));
    }
    Marshal.Copy(o,0,bd.Scan0,bytes); b.UnlockBits(bd);
  }
  static byte C(double v){int i=(int)Math.Round(v*255);return (byte)(i<0?0:(i>255?255:i));}
  static byte Ci(int i){return (byte)(i<0?0:(i>255?255:i));}
}
"@ -ReferencedAssemblies System.Drawing
[GradeF]::Run($crop)

function SaveJpg($bmp,$path,$q){
  $enc=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|Where-Object{$_.MimeType -eq 'image/jpeg'}
  $ep=New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,[long]$q)
  $bmp.Save($path,$enc,$ep)
}
SaveJpg $crop "$sp\ladenfront-edit-full.jpg" 94
$mw=1800; $nh=[int]($crop.Height*$mw/$crop.Width)
$web=New-Object System.Drawing.Bitmap($mw,$nh)
$gw=[System.Drawing.Graphics]::FromImage($web)
$gw.InterpolationMode='HighQualityBicubic';$gw.SmoothingMode='HighQuality';$gw.PixelOffsetMode='HighQuality'
$gw.DrawImage($crop,0,0,$mw,$nh);$gw.Dispose()
SaveJpg $web "$sp\ladenfront-edit-web.jpg" 90
$crop.Dispose();$web.Dispose()
Get-ChildItem "$sp\ladenfront-edit-*.jpg"|ForEach-Object{"{0}  {1} KB" -f $_.Name,[math]::Round($_.Length/1kb)}
