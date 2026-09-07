try{ Get-Content "pages-content.json" -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null; "JSON OK" } catch { "JSON FEHLER: " + $Error[0].Exception.Message }
