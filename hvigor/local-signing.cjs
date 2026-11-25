const fs = require('node:fs');
const path = require('node:path');

function applyLocalSigning(profile, projectRoot) {
  if ((profile.app?.signingConfigs || []).length > 0) {
    throw new Error('Keep signing materials out of build-profile.json5; use npm run signing:import.');
  }
  const file = path.join(projectRoot, '.local', 'signing.json');
  if (!fs.existsSync(file)) return profile;
  let local;
  try { local = JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch { throw new Error('Cannot read local signing configuration; credential values are omitted.'); }
  const fail = () => { throw new Error('Invalid local signing configuration; credential values are omitted.'); };
  if (!local || !Array.isArray(local.signingConfigs) || !Array.isArray(local.products) ||
      local.signingConfigs.length === 0 || local.products.length === 0) fail();
  const names = new Set();
  const fields = ['certpath', 'keyAlias', 'keyPassword', 'profile', 'signAlg', 'storeFile', 'storePassword'];
  for (const config of local.signingConfigs) {
    if (!config || typeof config.name !== 'string' || !/^[a-z0-9]{1,64}$/i.test(config.name) ||
        names.has(config.name) || !config.material ||
        !fields.every(field => typeof config.material[field] === 'string' && config.material[field].length > 0)) fail();
    names.add(config.name);
  }
  const products = (profile.app?.products || []).map(product => ({ ...product }));
  const bound = new Set();
  for (const binding of local.products) {
    if (!binding || typeof binding.name !== 'string' || bound.has(binding.name) || !names.has(binding.signingConfig)) fail();
    const product = products.find(item => item.name === binding.name);
    if (!product) fail();
    bound.add(binding.name);
    product.signingConfig = binding.signingConfig;
  }
  return { ...profile, app: { ...profile.app, signingConfigs: local.signingConfigs, products } };
}

module.exports = { applyLocalSigning };
