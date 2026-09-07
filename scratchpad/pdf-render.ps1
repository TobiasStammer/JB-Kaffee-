# Rendert PDF-Seiten via WinRT Windows.Data.Pdf zu PNG (Win10/11).
param([string]$InDir = 'C:\Homepage\Neue Seite 2026\Tee',
      [string]$OutDir = 'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\d6fde327-8546-442b-baa3-87d6a3b3766a\scratchpad\tee-render',
      [int]$TargetWidth = 900)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await($op, $t) { $m = $asTask.MakeGenericMethod($t); $task = $m.Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
function AwaitAction($op) { ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0].Invoke($null,@($op)).Wait(-1) | Out-Null }

[void][Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime]
[void][Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
[void][Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]

Get-ChildItem $InDir -Filter *.pdf | ForEach-Object {
  $slug = ($_.BaseName -replace '\s*\(.*$','' -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower()
  $sf = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($_.FullName)) ([Windows.Storage.StorageFile])
  $doc = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($sf)) ([Windows.Data.Pdf.PdfDocument])
  $page = $doc.GetPage(0)
  $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
  $opts.DestinationWidth = [uint32]$TargetWidth
  $ras = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  AwaitAction ($page.RenderToStreamAsync($ras, $opts))
  $ras.Seek(0)
  $reader = New-Object Windows.Storage.Streams.DataReader($ras)
  $size = [uint32]$ras.Size
  Await ($reader.LoadAsync($size)) ([uint32]) | Out-Null
  $bytes = New-Object byte[] $size
  $reader.ReadBytes($bytes)
  $out = Join-Path $OutDir "$slug.png"
  [IO.File]::WriteAllBytes($out, $bytes)
  $page.Dispose()
  "  $slug.png  ({0:N0} KB, {1}px)" -f ($bytes.Length/1kb), $TargetWidth
}
"fertig -> $OutDir"
