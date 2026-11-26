import { execFileSync } from 'node:child_process';
import { readFile, readdir, access, appendFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import JSON5 from 'json5';
import YAML from 'yaml';

const generated = new Set(['node_modules', 'oh_modules', 'build', '.hvigor', '.preview', '.git', '.local']);
export async function walk(directory) {
  const result = [];
  for (const item of await readdir(directory, { withFileTypes: true })) {
    if (generated.has(item.name) || item.isSymbolicLink()) continue;
    const file = path.join(directory, item.name);
    if (item.isDirectory()) result.push(...await walk(file)); else result.push(file);
  }
  return result;
}

function relative(root, file) { return path.relative(root, file).split(path.sep).join('/'); }
function inside(root, file) { const value = path.relative(root, file); return value !== '..' && !value.startsWith('..' + path.sep) && !path.isAbsolute(value); }
function imports(source) { return [...source.matchAll(/\bfrom\s+['"]([^'"]+)['"]/g)].map(item => item[1]); }
function parseConfig(file, source) { return file.endsWith('.json5') ? JSON5.parse(source) : JSON.parse(source); }
async function exists(file) { try { await access(file); return true; } catch { return false; } }
async function exactCaseExists(root, file) {
  if (!inside(root, file)) return false;
  let current = root;
  for (const part of path.relative(root, file).split(path.sep)) {
    if (!(await readdir(current)).includes(part)) return false;
    current = path.join(current, part);
  }
  return true;
}

export function repositoryFiles(root) {
  return [...new Set(execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean))];
}

export async function checkProject(root) {
  const problems = [];
  const json = async file => parseConfig(file, await readFile(path.join(root, file), 'utf8'));
  const product = await json('build-profile.json5');
  if (product.app?.signingConfigs?.length) problems.push('build-profile.json5: signing materials must stay in ignored .local/signing.json');
  const app = (await json('AppScope/app.json5')).app;
  if (!app || !/^[A-Za-z][\w]*(?:\.[A-Za-z][\w]*)+$/.test(app.bundleName || '')) problems.push('AppScope/app.json5: invalid bundleName');
  if (!product.app?.products?.some(item => item.name === 'default')) problems.push('build-profile.json5: missing default product');
  if (!product.modules?.length) problems.push('build-profile.json5: no registered modules');
  for (const file of ['oh-package.json5', 'hvigor/hvigor-config.json5', 'hvigorfile.ts', 'code-linter.json5']) if (!await exists(path.join(root, file))) problems.push(`${file}: missing`);
  const linter = await json('code-linter.json5');
  if (!linter.files?.includes('entry/src/main/ets/**/*.ets') || !linter.ruleSet?.includes('plugin:@typescript-eslint/recommended')) problems.push('code-linter.json5: native application code and recommended rules must be checked');
  for (const file of ['oh-package.json5', 'hvigor/hvigor-config.json5']) if ((await json(file)).modelVersion !== '5.0.0') problems.push(`${file}: unexpected modelVersion; review build tooling compatibility`);
  let references = 0, localImports = 0;
  const appResources = await resourceNames(path.join(root, 'AppScope/resources/base'));
  checkManifestResources('AppScope/app.json5', app, appResources, problems);
  for (const module of product.modules || []) {
    const moduleRoot = path.resolve(root, module.srcPath || '');
    if (!inside(root, moduleRoot) || moduleRoot === root) { problems.push(`module ${module.name}: source escapes module directory`); continue; }
    const prefix = relative(root, moduleRoot);
    const config = JSON5.parse(await readFile(path.join(moduleRoot, 'src/main/module.json5'), 'utf8')).module;
    if (config?.name !== module.name) problems.push(`${prefix}: module name differs from build-profile registration`);
    for (const name of ['build-profile.json5', 'oh-package.json5', 'hvigorfile.ts']) if (!await exists(path.join(moduleRoot, name))) problems.push(`${prefix}/${name}: missing`);
    const files = await walk(moduleRoot);
    for (const file of files.filter(item => /\.json5?$/.test(item))) {
      try { parseConfig(file, await readFile(file, 'utf8')); } catch { problems.push(`${relative(root, file)}: invalid JSON/JSON5`); }
    }
    const resources = new Set([...appResources, ...await resourceNames(path.join(moduleRoot, 'src/main/resources/base'))]);
    checkManifestResources(`${prefix}/src/main/module.json5`, config, resources, problems);
    for (const ability of config.abilities || []) {
      const source = path.resolve(moduleRoot, 'src/main', ability.srcEntry || '');
      if (!inside(moduleRoot, source) || !await exactCaseExists(root, source)) problems.push(`${prefix}: missing ability source ${ability.name}`);
    }
    if (config.type === 'entry') {
      if (!(config.abilities || []).some(ability => ability.name === config.mainElement)) problems.push(`${prefix}: mainElement does not name an ability`);
      if (!config.deviceTypes?.includes('tablet')) problems.push(`${prefix}: tablet device support is missing`);
    }
    if (config.pages) {
      const profileName = config.pages.match(/^\$profile:([\w]+)$/)?.[1];
      if (!profileName) problems.push(`${prefix}: unsupported pages profile reference`);
      else {
        const pages = JSON.parse(await readFile(path.join(moduleRoot, `src/main/resources/base/profile/${profileName}.json`), 'utf8'));
        if (!Array.isArray(pages.src) || !pages.src.length) problems.push(`${prefix}: pages profile is empty`);
        for (const page of pages.src || []) {
          const source = path.resolve(moduleRoot, 'src/main/ets', `${page}.ets`);
          if (!inside(moduleRoot, source) || !await exactCaseExists(root, source)) problems.push(`${prefix}: unresolvable page ${page}`);
        }
      }
    }
    for (const file of files.filter(item => /\.(ets|ts)$/.test(item))) {
      const source = await readFile(file, 'utf8');
      for (const specifier of imports(source).filter(item => item.startsWith('.'))) {
        const target = path.resolve(path.dirname(file), specifier);
        const candidates = path.extname(target) ? [target] : [target + '.ets', target + '.ts', path.join(target, 'Index.ets')];
        let found = false;
        for (const candidate of candidates) if (inside(root, candidate) && await exactCaseExists(root, candidate)) { found = true; break; }
        if (!found) problems.push(`${relative(root, file)}: unresolved or case-mismatched import ${specifier}`);
        localImports++;
      }
      for (const match of source.matchAll(/\$r\(['"]app\.([\w]+)\.([^'"]+)['"]\)/g)) {
        references++;
        if (!resources.has(`${match[1]}.${match[2]}`)) problems.push(`${relative(root, file)}: missing resource ${match[1]}.${match[2]}`);
      }
    }
  }
  return { problems, detail: `${product.modules?.length || 0} module(s), ${localImports} imports, ${references} code resource references` };
}

async function resourceNames(base) {
  const result = new Set();
  for (const file of await walk(base)) {
    const segments = relative(base, file).split('/');
    if (segments[0] === 'element' && file.endsWith('.json')) {
      const data = JSON.parse(await readFile(file, 'utf8'));
      for (const [kind, items] of Object.entries(data)) {
        const names = new Set();
        for (const item of items) {
          if (!item.name || names.has(item.name)) throw new Error(`${file}: empty or duplicate resource name`);
          names.add(item.name); result.add(`${kind}.${item.name}`);
        }
      }
    } else result.add(`${segments[0]}.${path.basename(file, path.extname(file))}`);
  }
  return result;
}

function checkManifestResources(file, value, names, problems) {
  for (const match of JSON.stringify(value).matchAll(/\$(string|color|media|profile):([\w]+)/g)) if (!names.has(`${match[1]}.${match[2]}`)) problems.push(`${file}: missing ${match[1]}.${match[2]}`);
}

export async function checkArchitecture(root) {
  const problems = [];
  const base = path.join(root, 'entry/src/main/ets');
  for (const file of (await walk(base)).filter(item => item.endsWith('.ets'))) {
    const name = relative(base, file);
    for (const specifier of imports(await readFile(file, 'utf8'))) {
      const target = specifier.startsWith('.') ? relative(base, path.resolve(path.dirname(file), specifier)) : specifier;
      if (name.startsWith('domain/') && !target.startsWith('domain/')) problems.push(`${name}: domain must not import ${specifier}`);
      if (name.startsWith('data/') && /^(app|features|pages|shared)\//.test(target)) problems.push(`${name}: data must not depend on UI or composition`);
      if (name.startsWith('shared/') && /^(app|data|features|pages)\//.test(target)) problems.push(`${name}: shared UI must not depend on features or data`);
      if (name.startsWith('features/') && /^(data|app)\//.test(target)) problems.push(`${name}: inject repository interfaces instead of importing implementations`);
      if (name.endsWith('ViewModel.ets') && /^(?:@kit\/|@ohos\.)/.test(specifier)) problems.push(`${name}: platform calls belong in adapters, not ViewModels`);
    }
  }
  return { problems, detail: 'domain/data/features/shared dependency direction' };
}

export function inspectText(file, bytes) {
  const problems = [];
  if (/\.(?:p12|pfx|pem|key|jks|keystore|p7b|cer|csr|credentials\.json|local\.json)$/i.test(file) ||
      /(?:^|\/)(?:sign-config\.json5|\.sign\/)/i.test(file) ||
      /(^|\/)\.env(?:$|\.)/i.test(file) && !file.toLowerCase().endsWith('.env.example')) problems.push(`${file}: local credential or signing file`);
  if (bytes.includes(0)) return problems;
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { return [...problems, `${file}: invalid UTF-8 text`]; }
  if (/-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/.test(text)) problems.push(`${file}: private key content`);
  if (/\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b/.test(text)) problems.push(`${file}: possible GitHub credential`);
  const secret = /["']?(?:storePassword|keyPassword|remix[_-]userkey|user_key|access_token|refresh_token|client_secret)["']?\s*[:=]\s*(["'])([^"'\r\n]+)\1/gi;
  for (const match of text.matchAll(secret)) if (!/^(?:<[^>]+>|\$\{[^}]+\}|(?:fake|test|demo|placeholder|example|synthetic)(?:[-_\w:.]*)?)$/i.test(match[2])) problems.push(`${file}: possible hard-coded secret (value omitted)`);
  for (const [index, line] of text.split(/\r?\n/).entries()) {
    if (/[\t ]+$/.test(line)) problems.push(`${file}:${index + 1}: trailing whitespace`);
    if (/^(?:<{7}\s|={7}$|>{7}\s)/.test(line)) problems.push(`${file}:${index + 1}: unresolved merge conflict`);
  }
  return problems;
}

export async function checkFiles(root, files = repositoryFiles(root)) {
  const problems = [];
  const ignored = execFileSync('git', ['ls-files', '--cached', '--ignored', '--exclude-standard', '-z'], { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean);
  for (const file of ignored) problems.push(`${file}: tracked despite ignore rules`);
  for (const file of files) {
    if (!/\.(?:ets|ts|mjs|cjs|js|json5?|ya?ml|md|ps1|sh|svg|p12|pfx|pem|key|jks|keystore|p7b|cer|csr)$|(^|\/)\.[^/]+$/i.test(file)) continue;
    let content;
    try {
      content = await readFile(path.join(root, file));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      // 未暂存的移动仍在索引中保留旧路径；检查索引内容，避免遗漏待提交的敏感文件。
      content = execFileSync('git', ['show', `:${file}`], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
    }
    problems.push(...inspectText(file, content));
  }
  return { problems, detail: `${files.length} versioned or pending source files; secret values are never printed` };
}

export async function checkWorkflows(root) {
  const problems = [];
  const directory = path.join(root, '.github/workflows');
  for (const file of (await walk(directory)).filter(item => /\.ya?ml$/.test(item))) {
    const workflow = YAML.parse(await readFile(file, 'utf8'));
    const label = relative(root, file);
    if (!workflow?.on || !workflow.jobs) { problems.push(`${label}: missing triggers or jobs`); continue; }
    if (workflow.on.pull_request_target !== undefined) problems.push(`${label}: pull_request_target is not allowed`);
    if (workflow.permissions?.contents !== 'read' || Object.values(workflow.permissions || {}).some(value => value === 'write')) problems.push(`${label}: expected read-only workflow permissions`);
    for (const job of Object.values(workflow.jobs)) {
      if (!job['timeout-minutes']) problems.push(`${label}: every job needs a timeout`);
      if (job.permissions && Object.values(job.permissions).some(value => value === 'write')) problems.push(`${label}: jobs must not elevate token permissions`);
      if (JSON.stringify(job['runs-on']).includes('self-hosted')) problems.push(`${label}: PR checks must use isolated GitHub-hosted runners`);
      for (const step of job.steps || []) {
        if (step.uses && !/^[\w.-]+\/[\w./-]+@[0-9a-f]{40}$/.test(step.uses)) problems.push(`${label}: action references must use full commit SHAs`);
        if (step['continue-on-error']) problems.push(`${label}: required steps must not ignore failures`);
      }
    }
    if (path.basename(file) === 'ci.yml') {
      if (!Object.hasOwn(workflow.on, 'push') || !Object.hasOwn(workflow.on, 'pull_request') || workflow.jobs.quality?.name !== 'Quality Gate') problems.push(`${label}: automatic Quality Gate triggers/name must remain stable`);
      if (!workflow.on.pull_request?.types?.includes('edited')) problems.push(`${label}: PR metadata edits must rerun the checks`);
      const native = workflow.jobs.harmony;
      if (native?.name !== 'HarmonyOS Gate' || native?.['runs-on'] !== 'ubuntu-24.04' || native.if || native['continue-on-error']) problems.push(`${label}: HarmonyOS Gate must always run on a hosted Ubuntu runner`);
      for (const command of ['bash scripts/ci/setup-harmony.sh', '-Task Install', '-Task Lint', '-Task Build']) {
        if (!native?.steps?.some(step => step.run?.includes(command) && !step.if)) problems.push(`${label}: missing unconditional native step ${command}`);
      }
    }
  }
  const ruleset = JSON.parse(await readFile(path.join(root, '.github/rulesets/main.json'), 'utf8'));
  const required = ruleset.rules?.find(rule => rule.type === 'required_status_checks')?.parameters;
  if (ruleset.enforcement !== 'active' || !ruleset.conditions?.ref_name?.include?.includes('refs/heads/main') || !ruleset.rules?.some(rule => rule.type === 'pull_request')) problems.push('main ruleset: active main PR protection is required');
  for (const name of ['Quality Gate', 'HarmonyOS Gate']) if (!required?.required_status_checks?.some(check => check.context === name && check.integration_id === 15368)) problems.push(`main ruleset: missing required GitHub Actions check ${name}`);
  if (!required?.strict_required_status_checks_policy) problems.push('main ruleset: branch must be up to date before merging');
  return { problems, detail: 'YAML, triggers, timeouts, action pins and token permissions' };
}

export function checkPullRequest(pullRequest) {
  const problems = [];
  if (!/^(feat|fix|chore|docs|refactor|test|ci|build|perf|style|revert)(\([\w./-]+\))?!?:\s+\S/.test(pullRequest.title || '') || !/[\u3400-\u9fff]/.test(pullRequest.title || '')) problems.push('PR title must use Conventional Commits with a Chinese summary');
  if (!/\bCloses\s+#\d+\b/i.test(pullRequest.body || '')) problems.push('PR description must contain Closes #<issue>');
  return { problems, detail: 'Conventional Commits title and linked issue' };
}

async function main() {
  const root = process.cwd();
  const checks = [['Project', () => checkProject(root)], ['Architecture', () => checkArchitecture(root)], ['Files', () => checkFiles(root)], ['Workflows', () => checkWorkflows(root)]];
  if (process.env.GITHUB_EVENT_NAME === 'pull_request') checks.push(['PR metadata', async () => checkPullRequest(JSON.parse(await readFile(process.env.GITHUB_EVENT_PATH, 'utf8')).pull_request)]);
  const rows = [];
  for (const [name, run] of checks) {
    let result;
    try { result = await run(); } catch (error) { result = { problems: [error.message], detail: 'check could not complete' }; }
    rows.push(`| ${name} | ${result.problems.length ? 'FAIL' : 'PASS'} |`);
    console.log(`${result.problems.length ? 'FAIL' : 'PASS'} ${name}: ${result.detail}`);
    for (const problem of result.problems) console.error(`  ${problem}`);
    if (result.problems.length) process.exitCode = 1;
  }
  if (process.env.GITHUB_STEP_SUMMARY) await appendFile(process.env.GITHUB_STEP_SUMMARY, `## Quality checks\n\n| Check | Result |\n| --- | --- |\n${rows.join('\n')}\n\nThese checks do not compile ArkUI or run a device.\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) await main();
