. "C:\Homepage\Neue Seite 2026\wp-lib.ps1"
$p = wp GET "/wp/v2/pages?slug=wartungserinnerung&context=edit"
$p | Select id,slug,parent,status,template | ConvertTo-Json
$p[0].content.raw.Length
$m = wp GET "/wp/v2/menu-items?per_page=100&context=edit"
$m | Select id,title,parent,menu_order,url,menus | ft | Out-String -Width 250
