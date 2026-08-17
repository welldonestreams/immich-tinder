# ============================================================
#  Immich Tinder - local app server (Windows PowerShell, no deps)
#
#  - Serves the web app (./web) at http://127.0.0.1:2293
#  - Setup wizard page: /setup.html  (first run: auto-opens)
#  - Proxies /api/* to your Immich server using config.json
#  - Config written by the wizard (POST /_setup)
#  - Loopback only - nothing is exposed to the network
#  - A small pool of workers serves requests concurrently, so downloading one
#    large video cannot stall every other request behind it
# ============================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$Port = 2293
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Web = Join-Path $Root 'web'
$ConfigFile = Join-Path $Root 'config.json'
$WorkerCount = 4

# Shared, thread-safe config. Target and ApiKey live together in ONE immutable
# object that /_setup replaces wholesale, rather than as two fields written one
# after the other. Synchronized() makes each individual field access atomic but
# not a compound read: a worker reading Target, then copying a request body,
# then reading ApiKey can have a /_setup land in between and end up sending the
# NEW key to the OLD server. A single reference swap makes that impossible -
# every request sees one config or the other, never half of each.
$State = [hashtable]::Synchronized(@{ Config = [pscustomobject]@{ Target = ''; ApiKey = '' } })
if (Test-Path $ConfigFile) {
    try {
        $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        $State.Config = [pscustomobject]@{ Target = [string]$cfg.target; ApiKey = [string]$cfg.apiKey }
    } catch { }
}

# .NET Framework allows only 2 concurrent connections per endpoint by default,
# which would cap the whole worker pool at 2 upstream calls no matter how many
# workers there are. Raise it before the first connection is made.
[System.Net.ServicePointManager]::DefaultConnectionLimit = 64

# One HttpClient for the whole process. One per request meant a fresh TCP+TLS
# handshake on every call; HttpClient is thread-safe and built to be shared.
# No timeout - a large original streams for as long as the client keeps reading.
$Http = [System.Net.Http.HttpClient]::new()
$Http.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan

$listener = New-Object System.Net.HttpListener
# Both spellings of loopback: the app stores location.origin, so whichever the
# user typed has to keep working.
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

$Worker = {
    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.Net.Http

    $Mime = @{
        '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript'; '.mjs' = 'text/javascript'
        '.css' = 'text/css'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'
        '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'; '.ico' = 'image/x-icon'
        '.json' = 'application/json'; '.woff2' = 'font/woff2'; '.txt' = 'text/plain'
    }
    $AllowedOrigins = @("http://127.0.0.1:$Port", "http://localhost:$Port")

    function Write-Json($res, $obj) {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json))
        $res.ContentType = 'application/json'
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    }

    # A page on some other origin must not be able to drive this proxy - it would
    # ride along on the API key we inject.
    #
    # Origin alone is NOT enough to decide this. Browsers attach it for non-safe
    # methods and CORS-mode requests, but omit it on cross-origin no-CORS
    # subresource loads - <img src>, <video src>, <link>, fetch(mode:'no-cors').
    # So "no Origin" does not mean "our own page": an <img> on any site the user
    # visits would otherwise reach /api/* with the real key attached.
    #
    # Sec-Fetch-Site closes that. It is a forbidden header name, so page JS
    # cannot forge it, and browsers do send it on subresource loads:
    #   same-origin -> our SPA's own fetches
    #   none        -> user typed the URL / bookmark
    #   cross-site  -> somebody else's page  (reject)
    # Non-browser local callers send neither header and still fall through; the
    # proxy is loopback-only and local processes remain an open question.
    function Test-SameOrigin($req) {
        $site = $req.Headers['Sec-Fetch-Site']
        if ($site) { return $site -in @('same-origin', 'none') }
        $origin = $req.Headers['Origin']
        if (-not $origin) { return $true }
        return $AllowedOrigins -contains $origin
    }

    while ($listener.IsListening) {
        try { $ctx = $listener.GetContext() } catch { break }
        $req = $ctx.Request
        $res = $ctx.Response
        $path = $req.Url.AbsolutePath
        # One snapshot for the whole request. Never read $State.Config twice -
        # that reintroduces the torn read this object exists to prevent.
        $conf = $State.Config
        try {
            # ---- reject cross-origin callers on anything that carries the key ----
            if (($path -eq '/_setup' -or $path -like '/api/*') -and -not (Test-SameOrigin $req)) {
                $res.StatusCode = 403
                Write-Json $res @{ error = 'cross-origin request rejected' }
                continue
            }
            # ---- setup: save config ----
            if ($path -eq '/_setup' -and $req.HttpMethod -eq 'POST') {
                $reader = [IO.StreamReader]::new($req.InputStream, $req.ContentEncoding)
                $body = $reader.ReadToEnd()
                $data = $body | ConvertFrom-Json
                # Build the whole config, then publish it with one reference
                # assignment. In-flight requests keep the old config to the end.
                $next = [pscustomobject]@{
                    Target = ([string]$data.target).TrimEnd('/')
                    ApiKey = [string]$data.apiKey
                }
                $State.Config = $next
                @{ target = $next.Target; apiKey = $next.ApiKey } | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
                Write-Json $res @{ ok = $true; configured = [bool]$next.Target }
                continue
            }
            # ---- setup: status ----
            if ($path -eq '/_setup/status') {
                Write-Json $res @{ configured = [bool]$conf.Target }
                continue
            }
            # ---- first run: redirect to the wizard ----
            if ($path -eq '/' -and -not $conf.Target) {
                $res.StatusCode = 302
                $res.RedirectLocation = '/setup.html'
                continue
            }
            # ---- proxy: /api/* -> Immich server ----
            if ($path -like '/api/*' -and $conf.Target) {
                $upstream = "$($conf.Target)$path"
                if ($req.Url.Query) { $upstream += $req.Url.Query }
                $method = New-Object System.Net.Http.HttpMethod($req.HttpMethod)
                $msg = [System.Net.Http.HttpRequestMessage]::new($method, $upstream)
                $resp = $null
                try {
                    # forward the request body for methods that carry one
                    if ($req.HttpMethod -in @('POST', 'PUT', 'PATCH', 'DELETE')) {
                        $ms = New-Object IO.MemoryStream
                        $req.InputStream.CopyTo($ms)
                        if ($ms.Length -gt 0) {
                            $msg.Content = [System.Net.Http.ByteArrayContent]::new($ms.ToArray())
                            if ($req.ContentType) {
                                $msg.Content.Headers.TryAddWithoutValidation('Content-Type', $req.ContentType) | Out-Null
                            }
                        }
                    }
                    # inject the API key (the wizard's key wins)
                    # same snapshot the upstream URL came from
                    if ($conf.ApiKey) {
                        $msg.Headers.TryAddWithoutValidation('x-api-key', $conf.ApiKey) | Out-Null
                    }
                    # ResponseHeadersRead streams the body through. The default
                    # buffers the entire response first - a whole video in memory
                    # before the browser sees a single byte.
                    $resp = $Http.SendAsync($msg, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
                    $res.StatusCode = [int]$resp.StatusCode
                    if ($resp.Content.Headers.ContentType) {
                        $res.ContentType = $resp.Content.Headers.ContentType.ToString()
                    }
                    if ($resp.Content.Headers.ContentLength) {
                        $res.ContentLength64 = [long]$resp.Content.Headers.ContentLength
                    }
                    $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    $stream.CopyTo($res.OutputStream)
                } finally {
                    if ($resp) { $resp.Dispose() }
                    $msg.Dispose()
                }
                continue
            }
            # ---- static files ----
            # setup.html lives at the app root (next to server.ps1), not in web/
            if ($path -eq '/setup.html') {
                $file = Join-Path $Root 'setup.html'
            } else {
                $file = Join-Path $Web ($path.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar))
                if ($path -eq '/') { $file = Join-Path $Web 'index.html' }
                if (-not (Test-Path $file) -or (Get-Item $file).PSIsContainer) {
                    $file = Join-Path $Web 'index.html'   # SPA fallback
                }
            }
            if (Test-Path $file) {
                $ext = [IO.Path]::GetExtension($file).ToLower()
                $bytes = [IO.File]::ReadAllBytes($file)
                $res.ContentType = if ($Mime.ContainsKey($ext)) { $Mime[$ext] } else { 'application/octet-stream' }
                $res.ContentLength64 = $bytes.Length
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $res.StatusCode = 404
            }
        } catch {
            try {
                $res.StatusCode = 500
                Write-Json $res @{ error = $_.Exception.Message }
            } catch { }
        } finally {
            try { $res.Close() } catch { }
        }
    }
}

Write-Host ''
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host '  Immich Tinder - local app' -ForegroundColor Cyan
Write-Host "  http://127.0.0.1:$Port" -ForegroundColor Cyan
Write-Host '  Close this window to stop the app.' -ForegroundColor Gray
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host ''

# Background workers. HttpListener is thread-safe and several threads calling
# GetContext() is the documented way to serve concurrently. The main thread is
# the last worker, so we start $WorkerCount - 1 here.
# A counted for-loop, not 1..($WorkerCount - 1): PowerShell's .. counts DOWN
# when the right side is smaller, so the range form spawns 2 workers for a
# WorkerCount of 1 and 3 for 0 - lowering the constant to disable concurrency
# would have silently added workers instead.
$ExtraWorkers = [Math]::Max(0, $WorkerCount - 1)
$pool = @()
for ($i = 1; $i -le $ExtraWorkers; $i++) {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('listener', $listener)
    $rs.SessionStateProxy.SetVariable('State', $State)
    $rs.SessionStateProxy.SetVariable('Http', $Http)
    $rs.SessionStateProxy.SetVariable('Web', $Web)
    $rs.SessionStateProxy.SetVariable('Root', $Root)
    $rs.SessionStateProxy.SetVariable('ConfigFile', $ConfigFile)
    $rs.SessionStateProxy.SetVariable('Port', $Port)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript($Worker.ToString()) | Out-Null
    $pool += [pscustomobject]@{ Shell = $ps; Runspace = $rs; Handle = $ps.BeginInvoke() }
}

try {
    # The main thread is a worker too, so closing the window still stops the app.
    & $Worker
} finally {
    try { $listener.Stop() } catch { }
    foreach ($w in $pool) {
        try { $w.Shell.Dispose() } catch { }
        try { $w.Runspace.Dispose() } catch { }
    }
    try { $Http.Dispose() } catch { }
    try { $listener.Close() } catch { }
}
