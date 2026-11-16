import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { registerHooks, stripTypeScriptTypes } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(import.meta.dirname, '..');
const sourceRoot = path.resolve(root, '../DSPONLINE');
const prefix = `${pathToFileURL(sourceRoot).href}/`;
const commit = '472bf62c76b695852b5577e563c1d113192ac731';

export function createFrozenSourceRuntime() {
  const git = (...args) => execFileSync('git', ['-c', `safe.directory=${sourceRoot.replaceAll('\\', '/')}`, '-C', sourceRoot, ...args], { encoding: 'utf8' }).trim();
  if (git('rev-parse', 'HEAD') !== commit || git('status', '--porcelain')) throw new Error('Frozen source revision or worktree changed');
  const catalogPath = path.join(root, 'tests/fixtures/parity/dsponline_source_catalog.json');
  const catalogBytes = fs.readFileSync(catalogPath);
  if (crypto.createHash('sha256').update(catalogBytes).digest('hex') !== fs.readFileSync(catalogPath.replace('.json', '.sha256'), 'utf8').trim()) throw new Error('Frozen catalog byte checksum mismatch');
  const frozen = JSON.parse(catalogBytes);
  if (frozen.source.commit !== commit) throw new Error('Catalog source revision changed');
  const files = {};
  const hooks = registerHooks({
    resolve(specifier, context, next) {
      if (context.parentURL?.startsWith(prefix) && specifier.startsWith('.') && !path.extname(specifier)) {
        const url = new URL(`${specifier}.ts`, context.parentURL);
        if (fs.existsSync(fileURLToPath(url))) return { url: url.href, shortCircuit: true };
      }
      return next(specifier, context);
    },
    load(url, context, next) {
      if (!url.startsWith(prefix) || !url.endsWith('.ts')) return next(url, context);
      const filename = fileURLToPath(url);
      const relative = path.relative(sourceRoot, filename).replaceAll('\\', '/');
      if (!relative.startsWith('src/game/')) throw new Error(`Unaudited source module outside game domain: ${relative}`);
      const bytes = fs.readFileSync(filename);
      const hash = crypto.createHash('sha256').update(bytes).digest('hex');
      if (frozen.source.files[relative] && frozen.source.files[relative] !== hash) throw new Error(`Source drift: ${relative}`);
      files[relative] = hash;
      let code = stripTypeScriptTypes(bytes.toString('utf8'), { mode: 'transform' });
      // Vite's production build supplies this host metadata. Keep dev-only
      // free-building and UI diagnostics disabled when executing in Node.
      code = 'import.meta.env = Object.freeze({DEV:false, PROD:true, MODE:"production"});\n' + code;
      if (relative === 'src/game/engine.ts') code += '\nexport {completeTechnology};\n';
      return { format: 'module', source: code, shortCircuit: true };
    },
  });
  return {
    commit,
    files,
    async load(name) {
      if (!/^[a-zA-Z][a-zA-Z0-9]*$/.test(name)) throw new Error('Invalid game module name');
      return import(pathToFileURL(path.join(sourceRoot, `src/game/${name}.ts`)).href);
    },
    readSource(relative) {
      if (!/^src\/(?:App\.tsx|components\/CampaignWorkspace\.tsx)$/.test(relative)) throw new Error('Unaudited UI source path');
      const bytes=fs.readFileSync(path.join(sourceRoot,relative));
      const hash=crypto.createHash('sha256').update(bytes).digest('hex');
      if(frozen.source.files[relative]&&frozen.source.files[relative]!==hash)throw new Error('Source drift: '+relative);
      files[relative]=hash;
      return bytes.toString('utf8');
    },
    unregisteredFiles() { return Object.keys(files).filter(file => !frozen.source.files[file]); },
    close() { hooks.deregister(); },
  };
}

// Explicit --register-source appends hashes of modules actually loaded by this
// run. It never updates a registered hash or any frozen catalog definition.
export function writeFrozenFixture(runtime, name, output) {
  if (!/^task27-[a-z-]+\.json$/.test(name)) throw new Error('Invalid fixture filename');
  const catalogPath = path.join(root, 'tests/fixtures/parity/dsponline_source_catalog.json');
  const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
  const missing = Object.keys(runtime.files).filter(file => !catalog.source.files[file]);
  if (missing.length && !process.argv.includes('--register-source')) throw new Error(`Unregistered source modules: ${missing.join(', ')}`);
  for (const [file, hash] of Object.entries(runtime.files)) {
    if (catalog.source.files[file] && catalog.source.files[file] !== hash) throw new Error(`Source drift: ${file}`);
    catalog.source.files[file] = hash;
  }
  if (missing.length) {
    const bytes = `${JSON.stringify(catalog, null, 2)}\n`;
    fs.writeFileSync(catalogPath, bytes);
    fs.writeFileSync(catalogPath.replace('.json', '.sha256'), `${crypto.createHash('sha256').update(bytes).digest('hex')}\n`);
    console.log(`Registered ${missing.length} additional frozen game modules`);
  }
  fs.writeFileSync(path.join(root, 'tests/fixtures/parity/behavior', name), `${JSON.stringify({ source_commit: runtime.commit, source_files: runtime.files, source_environment: { DEV: false, PROD: true, MODE: 'production' }, ...output }, null, 2)}\n`);
}
