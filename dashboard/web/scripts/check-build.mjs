// Validate committed source assets exactly; zlib versions may encode the same gzip payload differently.
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { readFileSync, readdirSync } from 'node:fs'
import { join, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { gunzipSync } from 'node:zlib'

const repo = fileURLToPath(new URL('../../../', import.meta.url))
const dist = join(repo, 'dashboard/static/app')
const git = args => execFileSync('git', args, { cwd: repo, encoding: 'utf8' }).split('\0').filter(Boolean)
const tracked = git(['ls-files', '-z', '--', 'dashboard/static/app']).sort()
function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const path = join(dir, entry.name)
    return entry.isDirectory() ? files(path) : [relative(repo, path).replaceAll('\\', '/')]
  })
}
assert.deepEqual(files(dist).sort(), tracked, 'Rebuilt asset set differs from committed files')
const changed = git(['diff', '--name-only', '-z', 'HEAD', '--', 'dashboard/static/app']).filter(path => !path.endsWith('.gz'))
assert.deepEqual(changed, [], 'Uncompressed build differs from committed sources')
let compressed = 0
for (const path of tracked) {
  if (!path.endsWith('.gz')) continue
  assert.deepEqual(gunzipSync(readFileSync(join(repo, path))), readFileSync(join(repo, path.slice(0, -3))), `Invalid gzip payload: ${path}`)
  compressed++
}
console.log(`Verified ${tracked.length} committed assets and ${compressed} gzip payloads`)
