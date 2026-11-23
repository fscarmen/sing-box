// Pre-compress the bundle; the panel serves *.gz when the browser accepts gzip.
import { readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { gzipSync } from 'node:zlib'

const dir = fileURLToPath(new URL('../../static/app/assets/', import.meta.url))
let saved = 0
for (const name of readdirSync(dir)) {
  if (!/\.(js|css|json|svg)$/.test(name)) continue
  const file = join(dir, name)
  const raw = readFileSync(file)
  if (raw.length < 1024) continue
  const gz = gzipSync(raw, { level: 9 })
  writeFileSync(file + '.gz', gz)
  saved += raw.length - gz.length
  console.log(name.padEnd(42), (raw.length / 1024).toFixed(0).padStart(6), 'KiB →', (gz.length / 1024).toFixed(0).padStart(5), 'KiB')
}
console.log('gzip saved', (saved / 1024).toFixed(0), 'KiB')
