const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const JSON5 = require('json5');
const crypto = require('node:crypto');
const { applyLocalSigning } = require('../../hvigor/local-signing.cjs');

function migrate(projectRoot) {
  const file = path.join(projectRoot, 'build-profile.json5');
  const original = JSON5.parse(fs.readFileSync(file, 'utf8'));
  const signingConfigs = original.app?.signingConfigs || [];
  if (!signingConfigs.length) throw new Error('No signing configuration to import.');
  // Confirm the ignore rule before writing any private configuration.
  execFileSync('git', ['check-ignore', '--quiet', '.local/signing.json'], { cwd: projectRoot, stdio: 'ignore' });
  const names = new Set(signingConfigs.map(item => item.name));
  const products = (original.app.products || []).filter(item => names.has(item.signingConfig))
    .map(item => ({ name: item.name, signingConfig: item.signingConfig }));
  if (products.length === 0) throw new Error('Associate a product with its signing configuration before importing.');
  const clean = { ...original, app: { ...original.app, signingConfigs: [], products: original.app.products.map(item => {
    const product = { ...item };
    if (names.has(product.signingConfig)) delete product.signingConfig;
    return product;
  }) } };
  const directory = path.join(projectRoot, '.local');
  const localFile = path.join(directory, 'signing.json');
  fs.mkdirSync(directory, { recursive: true });
  const temporary = `${file}.${crypto.randomUUID()}.tmp`;
  // Acquire ownership before writing, so a partial write can be cleaned up without deleting an existing file.
  const localDescriptor = fs.openSync(localFile, 'wx', 0o600);
  let temporaryOwned = false;
  try {
    try {
      fs.writeFileSync(localDescriptor, JSON.stringify({ signingConfigs, products }, null, 2) + '\n');
    } finally {
      fs.closeSync(localDescriptor);
    }
    applyLocalSigning(clean, projectRoot);
    const temporaryDescriptor = fs.openSync(temporary, 'wx', 0o600);
    temporaryOwned = true;
    try {
      fs.writeFileSync(temporaryDescriptor, JSON.stringify(clean, null, 2) + '\n');
    } finally {
      fs.closeSync(temporaryDescriptor);
    }
    fs.renameSync(temporary, file);
    temporaryOwned = false;
  } catch (error) {
    // Preserve the original failure if cleanup itself cannot complete.
    try { fs.unlinkSync(localFile); } catch {}
    throw error;
  } finally {
    if (temporaryOwned) {
      try { fs.unlinkSync(temporary); } catch {}
    }
  }
}

if (require.main === module) {
  try { migrate(process.cwd()); console.log('Signing configuration moved to ignored .local/signing.json; shared build profile contains no signing materials.'); }
  catch { console.error('Signing import failed. Check configuration, product association and existing local file; credential values are omitted.'); process.exitCode = 1; }
}
module.exports = { migrate };
