// Module scripts can execute before a stylesheet declared later in <head> has loaded.
// Chart canvases must not cache empty CSS custom properties during that interval.
export function waitForStyles(doc = document) {
  return Promise.all([...doc.querySelectorAll('link[rel~="stylesheet"]')].map(link => {
    if (link.sheet || link.disabled) return Promise.resolve()
    return new Promise((resolve, reject) => {
      const cleanup = () => {
        link.removeEventListener('load', loaded)
        link.removeEventListener('error', failed)
      }
      const loaded = () => { cleanup(); resolve() }
      const failed = () => { cleanup(); reject(new Error('Page stylesheet failed to load')) }
      link.addEventListener('load', loaded, { once: true })
      link.addEventListener('error', failed, { once: true })
    })
  }))
}
