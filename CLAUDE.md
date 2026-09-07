# kaffeetechniker.de – WordPress Integration

This project connects **Claude Code** (running locally on this machine) to the
WordPress site at `new.kaffeetechniker.de`, hosted on IONOS.

Connection details live in `kaffeetechniker-integration.env` in this same
folder. **Never print, log, or commit the contents of that file.** Load the
variables at the start of a session (e.g. `Get-Content .\kaffeetechniker-integration.env`
in PowerShell, or a small dotenv loader) rather than retyping the values.

## Working from two machines (Windows @ Firma, Mac @ zuhause)

The project files are kept in a **private Git repo**. The live WordPress site
is the shared state; this repo is the shared *source* (generator scripts +
content JSON + image originals).

- **Start of every session:** `git pull` before doing anything.
- **End of every session:** `git add -A && git commit -m "..." && git push`.
- `kaffeetechniker-integration.env` is git-ignored and lives **only** on each
  machine locally. It was copied over by hand once, never through git.
- On the Mac, the `.ps1` scripts run with **PowerShell 7** (`pwsh` –
  `brew install powershell`). The main scripts use `$PSScriptRoot`, so they
  work unchanged on either OS. Note: PS 7 on Mac is UTF-8 by default, so the
  PS 5.1 ANSI/umlaut workarounds (HTML entities, `\uXXXX`) are still correct
  but less critical there.
- If `git pull` reports a conflict, stop and resolve it with the user before
  pushing – don't force.

## Two ways to work on this site

### 1. Content changes (posts, pages, media, users, settings)
Use the **WordPress REST API** with the Application Password already
provisioned for this integration (`WP_APP_USER` / `WP_APP_PASSWORD` in the
.env, scoped to the `claude-integration` user — do not use the site admin's
own login).

Example (read-only check):

```powershell
$user = $env:WP_APP_USER
$pass = $env:WP_APP_PASSWORD -replace ' ',''
$pair = "$user`:$pass"
$b64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
Invoke-RestMethod -Uri "$env:WP_URL/wp-json/wp/v2/users/me" -Headers @{Authorization = "Basic $b64"}
```

If that returns the `claude-integration` user, the REST API connection
works. From there, standard `wp/v2` endpoints (`/posts`, `/pages`, `/media`,
`/plugins`, `/themes`, etc.) can read and write content. This is the safest
and most reversible way to make changes — every change is a normal,
auditable WordPress action tied to that user account.

### 2. Theme/plugin PHP file changes
The REST API alone won't let you edit PHP files. For that you need the
SFTP/SSH access in the .env (`IONOS_HOST`, `IONOS_USER`, `IONOS_PASSWORD`,
`IONOS_PORT`). Two options, easiest first:

- **Mount the site as a local drive** with an SFTP client (e.g. SSHFS-Win /
  WinFsp, or "Map Network Drive" via an SFTP tool such as SFTP Net Drive).
  Once mounted (e.g. to a drive letter), `wp-content/themes/...` and
  `wp-content/plugins/...` appear as ordinary local folders and Claude Code
  can read/edit files there directly, same as any local project.
- **Per-file SFTP** using the built-in Windows OpenSSH client (`sftp -P 22
  <user>@<host>`) to pull a file down, edit it locally, then push it back up.
  Slower, but needs no extra software.

Always test changes on a copy first where possible, and check the site after
each change (`$env:WP_URL`) before moving on to the next file.

## Security notes
- This .env contains a live SSH password in plain text. Recommend rotating
  IONOS SSH access to a key pair when convenient, and adding
  `kaffeetechniker-integration.env` to `.gitignore` if this folder is ever
  put under version control.
- The WP Application Password is scoped to one user (`claude-integration`)
  and can be revoked independently from wp-admin → Users → claude-integration
  → Application Passwords, without affecting the main admin login.
