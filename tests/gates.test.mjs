import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cp, mkdtemp, readFile, writeFile, rm, realpath } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import YAML from 'yaml';
import { checkProject, checkArchitecture, checkWorkflows, inspectText, checkPullRequest } from '../scripts/ci/check.mjs';

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
