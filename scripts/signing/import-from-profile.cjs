const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const JSON5 = require('json5');
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
  // Exclusive creation protects an existing local signing file from being overwritten.
  fs.writeFileSync(localFile, JSON.stringify({ signingConfigs, products }, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
  try { applyLocalSigning(clean, projectRoot); }
  catch (error) { fs.unlinkSync(localFile); throw error; }
  fs.writeFileSync(file, JSON.stringify(clean, null, 2) + '\n');
}

if (require.main === module) {
  try { migrate(process.cwd()); console.log('Signing configuration moved to ignored .local/signing.json; shared build profile contains no signing materials.'); }
  catch { console.error('Signing import failed. Check configuration, product association and existing local file; credential values are omitted.'); process.exitCode = 1; }
}
module.exports = { migrate };
