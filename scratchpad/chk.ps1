$ErrorActionPreference = 'Continue'
$root = 'C:\Homepage\Neue Seite 2026'
. "$root\wp-lib.ps1" | Out-Null

function try1($label, $path) {
  try { $r = wp GET $path; Write-Host ("OK  {0}: {1} item(s)" -f $label, (@($r).Count)); @($r) | ForEach-Object { Write-Host ("     id={0} slug={1} status={2} type={3} title={4}" -f $_.id,$_.slug,$_.status,$_.type,$_.title.rendered) } }
  catch { Write-Host ("ERR {0}: {1}" -f $label, $_.Exception.Message.Split("`n")[0]) }
}

try1 'users/me'            '/wp/v2/users/me?_fields=id,slug,name,roles,capabilities'
try1 'pages slug=nivona (pub)' '/wp/v2/pages?slug=nivona&_fields=id,slug,status,title'
try1 'pages slug=nivona-2'  '/wp/v2/pages?slug=nivona-2&_fields=id,slug,status,title'
try1 'posts slug=nivona'    '/wp/v2/posts?slug=nivona&_fields=id,slug,status,title'
try1 'media slug=nivona'    '/wp/v2/media?slug=nivona&_fields=id,slug,status,title'
try1 'search nivona'        '/wp/v2/search?search=nivona&_fields=id,title,url,subtype,type'
try1 'pages/1073'           '/wp/v2/pages/1073?_fields=id,slug,status,title,link'
try1 'pages/1074'           '/wp/v2/pages/1074?_fields=id,slug,status,title,link'
