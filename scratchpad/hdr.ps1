$ErrorActionPreference='Stop'
. "C:\Homepage\Neue Seite 2026\wp-lib.ps1" | Out-Null
$tps = wp GET '/wp/v2/template-parts?context=edit'
foreach($s in 'header','header-with-center-logo-and-social'){
  $tp = $tps | Where-Object { $_.slug -eq $s } | Select-Object -First 1
  if($tp){ Write-Host "===== $s (id=$($tp.id)) ====="; Write-Host $tp.content.raw }
}
