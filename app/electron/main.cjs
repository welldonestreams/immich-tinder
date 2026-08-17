// Electron main process for Immich Tinder (desktop edition).
//
// The renderer is served from a tiny loopback HTTP server instead of file://.
// Vite builds ES-module bundles, and Chromium refuses to execute module
// scripts from file:// (CORS), which produced a blank window. Serving over
// http://127.0.0.1:<port> behaves exactly like the web version.
//
// Security notes:
//  - The server binds to 127.0.0.1 only (loopback, no LAN exposure).
//  - webSecurity:false lets the renderer call the user's Immich API
//    cross-origin (the app only talks to the server URL the user typed).
const { app, BrowserWindow, Menu } = require('electron')
const path = require('path')
const http = require('http')
const fs = require('fs')

const DEV_URL = process.env.VITE_DEV_SERVER_URL

// Renderer diagnostics land here (console errors, load failures, crashes)
const logPath = path.join(app.getPath('userData'), 'error.log')
function log(msg) {
  try {
    fs.appendFileSync(logPath, `[${new Date().toISOString()}] ${msg}\n`)
  } catch {
    /* ignore */
  }
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
  '.woff2': 'font/woff2',
}

function startLocalServer(win) {
  const root = path.join(__dirname, '..', 'dist')

  const server = http.createServer((req, res) => {
    let p
    try {
      p = decodeURIComponent((req.url || '/').split('?')[0])
    } catch {
      p = '/'
    }
    if (p === '/') p = '/index.html'

    const file = path.join(root, p)
    // Path safety: refuse anything that escapes the dist directory
    if (file !== root && !file.startsWith(root + path.sep)) {
      res.writeHead(403)
      res.end('forbidden')
      return
    }

    fs.readFile(file, (err, data) => {
      if (err) {
        // SPA fallback: unknown paths get index.html (same as the nginx proxy)
        fs.readFile(path.join(root, 'index.html'), (err2, html) => {
          if (err2) {
            res.writeHead(404)
            res.end('not found')
            return
          }
          res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
          res.end(html)
        })
        return
      }
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
        'Cache-Control': 'no-cache',
      })
      res.end(data)
    })
  })

  server.listen(0, '127.0.0.1', () => {
    const port = server.address().port
    win.loadURL(`http://127.0.0.1:${port}/index.html`)
  })
  server.on('error', (err) => {
    console.error('local server failed:', err)
  })
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1100,
    height: 800,
    minWidth: 480,
    minHeight: 640,
    backgroundColor: '#000000',
    title: 'Immich Tinder',
    autoHideMenuBar: true,
    webPreferences: {
      webSecurity: false,
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'preload.cjs'),
    },
  })

  // Wizard help links (server URL / API key docs) open in the system browser
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/i.test(url)) {
      require('electron').shell.openExternal(url)
    }
    return { action: 'deny' }
  })

  // Diagnostics: capture renderer errors + load failures to error.log
  win.webContents.on('console-message', (event, level, message, line, sourceId) => {
    if (level >= 2) log(`console:${level} ${message} (${sourceId}:${line})`)
  })
  win.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedURL) => {
    log(`did-fail-load ${errorCode} ${errorDescription} ${validatedURL}`)
  })
  win.webContents.on('render-process-gone', (event, details) => {
    log(`render-process-gone ${details.reason}`)
  })
  log(`window created; version=${app.getVersion()}; userData=${app.getPath('userData')}`)

  if (DEV_URL) {
    win.loadURL(DEV_URL)
    win.webContents.openDevTools({ mode: 'detach' })
  } else {
    startLocalServer(win)
  }
}

const gotLock = app.requestSingleInstanceLock()
if (!gotLock) {
  app.quit()
} else {
  app.on('second-instance', () => {
    const [win] = BrowserWindow.getAllWindows()
    if (win) {
      if (win.isMinimized()) win.restore()
      win.focus()
    }
  })

  app.whenReady().then(() => {
    Menu.setApplicationMenu(null)
    createWindow()
    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) createWindow()
    })
  })

  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit()
  })
}
