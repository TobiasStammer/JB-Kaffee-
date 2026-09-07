Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web
$path = 'Z:\Dokumente\Firmengeschichte.docx'
$z = [IO.Compression.ZipFile]::OpenRead($path)
$e = $z.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
$sr = New-Object IO.StreamReader($e.Open())
$xml = $sr.ReadToEnd(); $sr.Close(); $z.Dispose()
$t = $xml -replace '</w:p>', "`n"
$t = $t -replace '<w:tab[^>]*/>', "`t"
$t = $t -replace '<[^>]+>', ''
$t = [System.Web.HttpUtility]::HtmlDecode($t)
$t = ($t -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join "`n"
Set-Content -Path 'C:\Homepage\Neue Seite 2026\scratchpad\firmengeschichte.txt' -Value $t -Encoding UTF8
Write-Host "Zeichen: $($t.Length)"
