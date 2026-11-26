import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cp, mkdtemp, readFile, writeFile, rm, realpath, mkdir as fsMkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import YAML from 'yaml';
import JSON5 from 'json5';
import signing from '../hvigor/local-signing.cjs';
import importer from '../scripts/signing/import-from-profile.cjs';
import { checkProject, checkArchitecture, checkFiles, checkWorkflows, inspectText, checkPullRequest } from '../scripts/ci/check.mjs';

const root = process.cwd();
async function fixture(t) {
  const parent = await realpath(tmpdir());
  const directory = await mkdtemp(path.join(parent, 'library-hm-ci-'));
  t.after(async () => {
    const resolved = path.resolve(directory);
    if (path.dirname(resolved) !== parent || !path.basename(resolved).startsWith('library-hm-ci-')) throw new Error('Refusing to remove an unexpected fixture path');
    await rm(resolved, { recursive: true, force: true });
  });
  const ignored = new Set(['build', 'oh_modules', 'node_modules', '.hvigor', '.preview']);
  for (const name of ['AppScope', 'entry', 'hvigor', '.github', 'build-profile.json5', 'oh-package.json5', 'hvigorfile.ts', 'code-linter.json5']) {
    await cp(path.join(root, name), path.join(directory, name), { recursive: true, filter: file => !file.split(path.sep).some(part => ignored.has(part)) });
  }
  return directory;
}

test('valid project and JSON5 comments/trailing commas pass', async t => {
  const directory = await fixture(t); const file = path.join(directory, 'build-profile.json5');
  const source = await readFile(file, 'utf8'); await writeFile(file, '// JSON5 fixture\n' + source.replace(/\n}\s*$/, ',\n}\n'));
  assert.deepEqual((await checkProject(directory)).problems, []);
});

test('file gate scans moved resources and retains credential checks for missing indexed files', async t => {
  const directory = await fixture(t);
  const git = args => {
    const result = spawnSync('git', args, { cwd: directory, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
  };
  git(['init', '--quiet']);
  await writeFile(path.join(directory, 'old.svg'), '<svg/>\n');
  git(['add', '--', 'old.svg']);
  await rm(path.join(directory, 'old.svg'));
  await writeFile(path.join(directory, 'new.svg'), '<svg/>\n');
  assert.deepEqual((await checkFiles(directory)).problems, []);
  await writeFile(path.join(directory, 'new.svg'), '<svg/>  \n');
  assert.ok((await checkFiles(directory)).problems.some(problem => problem.includes('new.svg')));
  await writeFile(path.join(directory, 'old.svg'), '-----BEGIN ' + 'PRIVATE KEY-----\n');
  git(['add', '--', 'old.svg']);
  await rm(path.join(directory, 'old.svg'));
  assert.ok((await checkFiles(directory)).problems.some(problem => problem.includes('old.svg') && problem.includes('private key')));
});

test('both color modes have matching resources, legible text and qualified icons', async () => {
  const resources = path.join(root, 'entry/src/main/resources');
  const palette = async mode => Object.fromEntries(JSON.parse(
    await readFile(path.join(resources, mode, 'element/color.json'), 'utf8')).color.map(c => [c.name, c.value]));
  const base = await palette('base'), dark = await palette('dark');
  assert.deepEqual(Object.keys(base).sort(), Object.keys(dark).sort());
  const luminance = hex => {
    const rgb = hex.slice(1).match(/../g).map(c => parseInt(c, 16) / 255)
      .map(c => c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
  };
  const contrast = (a, b) => (Math.max(luminance(a), luminance(b)) + 0.05) /
    (Math.min(luminance(a), luminance(b)) + 0.05);
  for (const colors of [base, dark]) {
    for (const surface of ['surface', 'surface_subtle', 'app_background']) {
      for (const text of ['text_primary', 'text_secondary', 'text_muted']) {
        assert.ok(contrast(colors[surface], colors[text]) >= 4.5, `${surface}/${text}`);
      }
    }
    assert.ok(contrast(colors.brand_primary, colors.on_accent) >= 4.5);
    assert.ok(contrast(colors.brand_primary, colors.demo_background) >= 4.5, 'selected navigation label');
    assert.ok(contrast(colors.text_muted, colors.surface) >= 4.5, 'unselected navigation label');
  }
  assert.notEqual(base.app_background, dark.app_background);
  assert.notEqual(base.shelf_middle, dark.shelf_middle);
  for (const icon of ['home', 'home_active', 'shelf', 'shelf_active', 'plus', 'search',
    'close', 'chevron', 'user_active', 'bookmark_active']) {
    const light = await readFile(path.join(resources, 'base/media', `ic_${icon}.svg`), 'utf8');
    const night = await readFile(path.join(resources, 'dark/media', `ic_${icon}.svg`), 'utf8');
    assert.notEqual(light, night, icon);
  }
});

test('broken static resources and missing pages fail the project gate', async t => {
  const directory = await fixture(t);
  const colors = path.join(directory, 'entry/src/main/resources/base/element/color.json');
  const data = JSON.parse(await readFile(colors, 'utf8')); data.color = data.color.filter(item => item.name !== 'brand_primary');
  await writeFile(colors, JSON.stringify(data));
  await writeFile(path.join(directory, 'entry/src/main/resources/base/profile/main_pages.json'), '{"src":["pages/Missing"]}');
  const { problems } = await checkProject(directory);
  assert.ok(problems.some(item => item.includes('brand_primary')));
  assert.ok(problems.some(item => item.includes('unresolvable page')));
});

test('resource JSON remains strict even though build configuration accepts JSON5', async t => {
  const directory = await fixture(t); const file = path.join(directory, 'entry/src/main/resources/base/element/color.json');
  await writeFile(file, '// invalid JSON resource\n' + await readFile(file, 'utf8'));
  await assert.rejects(checkProject(directory), SyntaxError);
});

test('incorrect import casing fails even on case-insensitive Windows filesystems', async t => {
  const directory = await fixture(t); const file = path.join(directory, 'entry/src/main/ets/features/home/HomeViewModel.ets');
  await writeFile(file, (await readFile(file, 'utf8')).replace("model/Book'", "model/book'"));
  assert.ok((await checkProject(directory)).problems.some(item => item.includes('case-mismatched import')));
});

test('domain and feature dependencies cannot bypass repository boundaries', async t => {
  const directory = await fixture(t);
  for (const name of ['domain/model/Book.ets', 'features/home/HomeViewModel.ets']) {
    const file = path.join(directory, 'entry/src/main/ets', name);
    await writeFile(file, (await readFile(file, 'utf8')) + "\nimport { DemoFileImporter } from '../../data/demo/DemoFileImporter';\n");
  }
  const { problems } = await checkArchitecture(directory);
  assert.ok(problems.some(item => item.includes('domain must not import')));
  assert.ok(problems.some(item => item.includes('inject repository')));
});

test('credential files, private keys and common embedded credentials are rejected without echoing values', () => {
  assert.ok(inspectText('signing.p12', Buffer.from([0, 1])).length);
  const privateHeader = '-----BEGIN ' + 'PRIVATE KEY-----';
  assert.ok(inspectText('private.pem', Buffer.from(privateHeader)).some(item => item.includes('private key')));
  const field = ['remix', 'userkey'].join('_'); const secret = 'non-placeholder-literal';
  const problems = inspectText('config.json', Buffer.from(JSON.stringify({ [field]: secret })));
  assert.ok(problems.some(item => item.includes('hard-coded secret'))); assert.ok(!JSON.stringify(problems).includes(secret));
  const token = 'gh' + 'p_' + 'x'.repeat(36);
  assert.ok(inspectText('fixture.txt', Buffer.from(token)).some(item => item.includes('GitHub credential')));
  assert.deepEqual(inspectText('.env.example', Buffer.from('EXAMPLE=placeholder\n')), []);
  for (const file of ['debug.p7b', 'debug.cer', 'debug.csr', 'private.pem', 'private.key', 'sign-config.json5', '.sign/sign-config.json5']) {
    assert.ok(inspectText(file, Buffer.from('{}')).some(item => item.includes('signing file')));
  }
});

async function signingFixture(t) {
  const directory = await mkdtemp(path.join(await realpath(tmpdir()), 'library-hm-signing-'));
  t.after(async () => {
    if (!path.basename(directory).startsWith('library-hm-signing-') || path.dirname(directory) !== await realpath(tmpdir())) throw new Error('Unexpected signing fixture path');
    await rm(directory, { recursive: true, force: true });
  });
  return directory;
}

function syntheticSigning() {
  return { signingConfigs: [{ name: 'default', type: 'HarmonyOS', material: {
    certpath: 'synthetic.cer', keyAlias: 'synthetic-alias', keyPassword: 'synthetic-key-password',
    profile: 'synthetic.p7b', signAlg: 'SHA256withECDSA', storeFile: 'synthetic.p12', storePassword: 'synthetic-store-password'
  } }], products: [{ name: 'default', signingConfig: 'default' }] };
}

test('signing ignores cover nested directories and mixed-case extensions on case-sensitive Git', async t => {
  const directory = await signingFixture(t);
  assert.equal(spawnSync('git', ['init', '--quiet'], { cwd: directory }).status, 0);
  await writeFile(path.join(directory, '.gitignore'), await readFile(path.join(root, '.gitignore')));
  const names = ['.sign/file.json', 'entry/.sign/file.json', 'sign-config.json5', 'entry/sign-config.json5',
    'entry/private.KEY', 'nested/private.P12', 'private.PfX', 'private.JkS', 'private.KeyStore',
    'private.P7B', 'private.PeM', 'private.CeR', 'private.CsR'];
  const result = spawnSync('git', ['-c', 'core.ignorecase=false', 'check-ignore', '--no-index', '--stdin'],
    { cwd: directory, input: names.join('\n') + '\n', encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split(/\r?\n/), names);
});

test('file gate inspects key and certificate files before any extension can bypass credential checks', async t => {
  const directory = await signingFixture(t);
  assert.equal(spawnSync('git', ['init', '--quiet'], { cwd: directory }).status, 0);
  await fsMkdir(path.join(directory, 'nested'));
  const names = ['nested/private.key', 'nested/private.pem', 'nested/private.cer', 'nested/private.csr',
    'nested/private.KEY', 'nested/private.P12', 'nested/private.PfX', 'nested/private.JkS',
    'nested/private.KeyStore', 'nested/private.P7B', 'nested/SIGN-CONFIG.JSON5', '.ENV'];
  for (const name of names) await writeFile(path.join(directory, name), Buffer.from([0, 1]));
  const { problems } = await checkFiles(directory, names);
  for (const name of names) assert.ok(problems.some(problem => problem.startsWith(`${name}:`) &&
    problem.includes('signing file')), name);
});

test('shared project gate rejects signing materials without showing values', async t => {
  const directory = await fixture(t);
  const file = path.join(directory, 'build-profile.json5');
  const profile = JSON5.parse(await readFile(file, 'utf8'));
  profile.app.signingConfigs = syntheticSigning().signingConfigs;
  await writeFile(file, JSON.stringify(profile));
  const { problems } = await checkProject(directory);
  assert.ok(problems.some(item => item.includes('signing materials')));
  assert.ok(!JSON.stringify(problems).includes('synthetic-key-password'));
});

test('missing local signing file keeps unsigned builds and shared profile unchanged', async t => {
  const directory = await signingFixture(t);
  const profile = { app: { signingConfigs: [], products: [{ name: 'default' }] } };
  assert.equal(signing.applyLocalSigning(profile, directory), profile);
  assert.deepEqual(profile.app.signingConfigs, []);
});

test('local signing changes only the build context, preserving the shared file and other products', async t => {
  const directory = await signingFixture(t);
  const profile = { app: { signingConfigs: [], products: [{ name: 'default' }, { name: 'other' }] } };
  const source = JSON.stringify(profile);
  await writeFile(path.join(directory, 'build-profile.json5'), source);
  await fsMkdir(path.join(directory, '.local'));
  await writeFile(path.join(directory, '.local/signing.json'), JSON.stringify(syntheticSigning()));
  const configured = signing.applyLocalSigning(profile, directory);
  assert.equal(configured.app.products[0].signingConfig, 'default');
  assert.equal(configured.app.products[1].signingConfig, undefined);
  assert.equal(configured.app.signingConfigs[0].material.keyPassword, 'synthetic-key-password');
  assert.equal(JSON.stringify(profile), source);
  assert.equal(await readFile(path.join(directory, 'build-profile.json5'), 'utf8'), source);
});

test('invalid local signing and shared embedded materials fail without leaking input', async t => {
  const directory = await signingFixture(t);
  await fsMkdir(path.join(directory, '.local'));
  const file = path.join(directory, '.local/signing.json');
  const profile = { app: { signingConfigs: [], products: [{ name: 'default' }] } };
  await writeFile(file, '{invalid synthetic-sensitive-input');
  assert.throws(() => signing.applyLocalSigning(profile, directory), error => !error.message.includes('synthetic-sensitive-input'));
  const invalid = syntheticSigning(); invalid.products[0].name = 'missing';
  await writeFile(file, JSON.stringify(invalid));
  assert.throws(() => signing.applyLocalSigning(profile, directory), /Invalid local signing/);
  assert.throws(() => signing.applyLocalSigning({ app: { signingConfigs: syntheticSigning().signingConfigs } }, directory), /Keep signing materials out/);
});

test('signing import preserves product settings and moves materials to a Git-ignored file', async t => {
  const directory = await signingFixture(t);
  assert.equal(spawnSync('git', ['init', '--quiet'], { cwd: directory }).status, 0);
  await writeFile(path.join(directory, '.gitignore'), '.local/\n');
  const local = syntheticSigning();
  const profile = { app: { signingConfigs: local.signingConfigs, products: [{ name: 'default', signingConfig: 'default', compatibleSdkVersion: '5.0.0(12)' }] }, modules: [{ name: 'entry' }] };
  const file = path.join(directory, 'build-profile.json5');
  await writeFile(file, JSON.stringify(profile));
  importer.migrate(directory);
  const clean = JSON5.parse(await readFile(file, 'utf8'));
  assert.deepEqual(clean.app.signingConfigs, []);
  assert.equal(clean.app.products[0].signingConfig, undefined);
  assert.equal(clean.app.products[0].compatibleSdkVersion, '5.0.0(12)');
  assert.deepEqual(clean.modules, profile.modules);
  assert.deepEqual(JSON.parse(await readFile(path.join(directory, '.local/signing.json'), 'utf8')), local);
  const bytes = await readFile(path.join(directory, '.local/signing.json'), 'utf8');
  await writeFile(file, JSON.stringify(profile));
  assert.throws(() => importer.migrate(directory));
  assert.equal(await readFile(path.join(directory, '.local/signing.json'), 'utf8'), bytes);
  assert.deepEqual(JSON5.parse(await readFile(file, 'utf8')), profile);
});

for (const phase of ['local-write', 'temporary-write', 'replace']) {
  test(`signing import preserves the original profile and permits retry after ${phase} fails`, async t => {
    const directory = await signingFixture(t);
    assert.equal(spawnSync('git', ['init', '--quiet'], { cwd: directory }).status, 0);
    await writeFile(path.join(directory, '.gitignore'), '.local/\n');
    const profile = { app: { signingConfigs: syntheticSigning().signingConfigs,
      products: [{ name: 'default', signingConfig: 'default', compatibleSdkVersion: '5.0.0(12)' }] },
      modules: [{ name: 'entry', srcPath: './entry' }] };
    const file = path.join(directory, 'build-profile.json5');
    const original = '// Uncommitted SDK and module settings must survive exactly.\n' + JSON.stringify(profile, null, 2);
    await writeFile(file, original);
    const failure = Object.assign(new Error('synthetic I/O failure'), { code: phase === 'replace' ? 'EPERM' : 'ENOSPC' });
    const write = fs.writeFileSync;
    if (phase === 'replace') {
      t.mock.method(fs, 'renameSync', () => { throw failure; });
    } else {
      t.mock.method(fs, 'writeFileSync', (descriptor, data, ...args) => {
        const isLocal = JSON.parse(data).signingConfigs !== undefined;
        if (isLocal === (phase === 'local-write')) {
          write(descriptor, 'partial fixture');
          throw failure;
        }
        return write(descriptor, data, ...args);
      });
    }
    assert.throws(() => importer.migrate(directory), error => error === failure);
    t.mock.restoreAll();
    assert.equal(await readFile(file, 'utf8'), original);
    assert.deepEqual(fs.readdirSync(path.join(directory, '.local')), []);
    assert.deepEqual(fs.readdirSync(directory).filter(name => name.endsWith('.tmp')), []);
    importer.migrate(directory);
    const clean = JSON5.parse(await readFile(file, 'utf8'));
    assert.deepEqual(clean.modules, profile.modules);
    assert.equal(clean.app.products[0].compatibleSdkVersion, '5.0.0(12)');
    assert.deepEqual(clean.app.signingConfigs, []);
    assert.deepEqual(JSON.parse(await readFile(path.join(directory, '.local/signing.json'), 'utf8')).signingConfigs,
      profile.app.signingConfigs);
  });
}

test('signing import never deletes an existing temporary path on a creation collision', async t => {
  const directory = await signingFixture(t);
  assert.equal(spawnSync('git', ['init', '--quiet'], { cwd: directory }).status, 0);
  await writeFile(path.join(directory, '.gitignore'), '.local/\n');
  const file = path.join(directory, 'build-profile.json5');
  const original = JSON.stringify({ app: { signingConfigs: syntheticSigning().signingConfigs,
    products: [{ name: 'default', signingConfig: 'default' }] } });
  await writeFile(file, original);
  const temporary = `${file}.synthetic-collision.tmp`;
  await writeFile(temporary, 'unrelated existing content');
  t.mock.method(crypto, 'randomUUID', () => 'synthetic-collision');
  assert.throws(() => importer.migrate(directory), { code: 'EEXIST' });
  assert.equal(await readFile(file, 'utf8'), original);
  assert.equal(await readFile(temporary, 'utf8'), 'unrelated existing content');
  assert.deepEqual(fs.readdirSync(path.join(directory, '.local')), []);
});

test('trailing whitespace, invalid UTF-8 and conflict markers fail basic checks', () => {
  assert.ok(inspectText('source.ets', Buffer.from('value ' + '\n')).some(item => item.includes('trailing whitespace')));
  assert.ok(inspectText('source.ets', Buffer.from('<<<<<<<' + ' HEAD\n')).some(item => item.includes('merge conflict')));
  assert.ok(inspectText('source.ets', Buffer.from([0xff])).some(item => item.includes('UTF-8')));
});

test('workflow gate rejects mutable actions, elevated permissions and persistent PR runners', async t => {
  const directory = await fixture(t);
  const ci = path.join(directory, '.github/workflows/ci.yml');
  const workflow = YAML.parse(await readFile(ci, 'utf8')); workflow.jobs.quality.steps[0].uses = 'actions/checkout@v6';
  workflow.jobs.harmony['runs-on'] = ['self-hosted', 'harmonyos'];
  workflow.jobs.harmony.permissions = { contents: 'write' };
  await writeFile(ci, YAML.stringify(workflow));
  const { problems } = await checkWorkflows(directory);
  for (const fragment of ['full commit SHAs', 'isolated GitHub-hosted', 'elevate token']) assert.ok(problems.some(item => item.includes(fragment)));
});

test('native checks cannot be skipped or allowed to fail and PR edits trigger revalidation', async t => {
  const directory = await fixture(t); const ci = path.join(directory, '.github/workflows/ci.yml');
  const workflow = YAML.parse(await readFile(ci, 'utf8'));
  workflow.on.pull_request.types = ['opened', 'synchronize'];
  workflow.jobs.harmony.if = 'false';
  const lint = workflow.jobs.harmony.steps.find(step => step.run?.includes('-Task Lint'));
  lint['continue-on-error'] = true;
  workflow.jobs.harmony.steps = workflow.jobs.harmony.steps.filter(step => !step.run?.includes('-Task Build'));
  await writeFile(ci, YAML.stringify(workflow));
  const { problems } = await checkWorkflows(directory);
  for (const fragment of ['metadata edits', 'must always run', 'ignore failures', '-Task Build']) assert.ok(problems.some(item => item.includes(fragment)));
});

test('required remote checks must match the workflow job names and source app', async t => {
  const directory = await fixture(t); const file = path.join(directory, '.github/rulesets/main.json');
  const ruleset = JSON.parse(await readFile(file, 'utf8'));
  const status = ruleset.rules.find(rule => rule.type === 'required_status_checks');
  status.parameters.required_status_checks[1] = { context: 'Wrong native job', integration_id: 123 };
  await writeFile(file, JSON.stringify(ruleset));
  assert.ok((await checkWorkflows(directory)).problems.some(item => item.includes('missing required GitHub Actions check HarmonyOS Gate')));
});

test('PR title and issue link follow repository collaboration rules', () => {
  assert.deepEqual(checkPullRequest({ title: 'chore: 添加代码门禁', body: 'Closes #4' }).problems, []);
  assert.ok(checkPullRequest({ title: 'update code', body: 'no issue' }).problems.length >= 2);
});

test('actual CLI exits nonzero for an invalid PR while other checks pass', async t => {
  const directory = await fixture(t); const event = path.join(directory, 'event.json');
  await writeFile(event, JSON.stringify({ pull_request: { title: 'invalid', body: '' } }));
  const result = spawnSync(process.execPath, ['scripts/ci/check.mjs'], { cwd: root, encoding: 'utf8', env: { ...process.env, GITHUB_EVENT_NAME: 'pull_request', GITHUB_EVENT_PATH: event, GITHUB_STEP_SUMMARY: '' } });
  assert.equal(result.status, 1);
  assert.match(result.stdout, /PASS Project/); assert.match(result.stdout, /FAIL PR metadata/);
});
