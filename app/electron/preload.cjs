// Preload: runs in an isolated context before the page loads.
// Exposes a reliable desktop marker (userAgent checks can be unreliable),
// and nothing else — the renderer keeps zero Node access.
const { contextBridge } = require('electron')

contextBridge.exposeInMainWorld('desktopInfo', {
  isDesktop: true,
  version: process.env.npm_package_version || '0.0.0',
})
