import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm, realpath, copyFile, chmod, access } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { spawnSync, execFileSync } from 'node:child_process';
import path from 'node:path';

const nativeScript = path.resolve('scripts/ci/build-harmony.ps1');
const powershell = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
const quote = value => "'" + value.replaceAll("'", "''") + "'";

async function runNative(t, scenario = 'success', task = 'All') {
  const parent = await realpath(tmpdir());
  const directory = await mkdtemp(path.join(parent, 'library-hm-native-'));
  t.after(async () => {
    const resolved = path.resolve(directory);
    if (path.dirname(resolved) !== parent || !path.basename(resolved).startsWith('library-hm-native-')) throw new Error('Unexpected native fixture path');
    await rm(resolved, { recursive: true, force: true });
  });
  await mkdir(path.join(directory, 'entry'));
  await mkdir(path.join(directory, '.local/ci/reports'), { recursive: true });
  // A previous successful report must never hide a missing report from this run.
  await writeFile(path.join(directory, '.local/ci/reports/codelinter.json'), '[]');
  await copyFile('code-linter.json5', path.join(directory, 'code-linter.json5'));
  const callLog = path.join(directory, 'calls.txt');
  const wrapper = path.join(directory, 'mock-tools.ps1');
  await writeFile(wrapper, `
$ErrorActionPreference = 'Stop'
$global:LASTEXITCODE = 0
$global:fixtureRoot = ${quote(directory)}
$global:callLog = ${quote(callLog)}
function global:ohpm {
  [IO.File]::AppendAllText($global:callLog, 'ohpm ' + ($args -join ' ') + [Environment]::NewLine)
  $global:LASTEXITCODE = 0
  if ($env:NATIVE_TEST_SCENARIO -eq 'install-error') { $global:LASTEXITCODE = 9 }
}
function global:codelinter {
  [IO.File]::AppendAllText($global:callLog, 'codelinter ' + ($args -join ' ') + [Environment]::NewLine)
  $index = [Array]::IndexOf($args, '--output')
  if ($index -lt 0 -or $args -contains '--exit-on') { throw 'Unsupported Code Linter 5.1 command' }
  $global:LASTEXITCODE = 0
  if ($env:NATIVE_TEST_SCENARIO -ne 'missing-report') {
    $reportContent = '[]'
    if ($env:NATIVE_TEST_SCENARIO -eq 'invalid-report') { $reportContent = 'invalid json' }
    if ($env:NATIVE_TEST_SCENARIO -eq 'schema-error') { $reportContent = '{}' }
    if ($env:NATIVE_TEST_SCENARIO -eq 'error-report') { $reportContent = '[{"filePath":"demo.ets","messages":[{"severity":"error"}]}]' }
    if ($env:NATIVE_TEST_SCENARIO -eq 'warning-report') { $reportContent = '[{"filePath":"demo.ets","messages":[{"severity":"warn"}]}]' }
    if ($env:NATIVE_TEST_SCENARIO -eq 'unknown-severity') { $reportContent = '[{"filePath":"demo.ets","messages":[{"severity":"unexpected"}]}]' }
    [IO.File]::WriteAllText($args[$index + 1], $reportContent)
  }
  if ($env:NATIVE_TEST_SCENARIO -eq 'tool-diagnostic-error') { Write-Output (([string][char]27) + '[31mInternal check failure') }
  if ($env:NATIVE_TEST_SCENARIO -eq 'lint-error') { $global:LASTEXITCODE = 4 }
}
function global:hvigorw {
  [IO.File]::AppendAllText($global:callLog, 'hvigorw ' + ($args -join ' ') + [Environment]::NewLine)
  $global:LASTEXITCODE = 0
  if ($env:NATIVE_TEST_SCENARIO -eq 'build-error') { $global:LASTEXITCODE = 7; return }
  if (($args -contains 'assembleHap') -and $env:NATIVE_TEST_SCENARIO -ne 'missing-hap') {
    $output = Join-Path $global:fixtureRoot 'entry/build/default/outputs/default'
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $bytes = [byte[]](80, 75, 3, 4)
    if ($env:NATIVE_TEST_SCENARIO -eq 'empty-hap') { $bytes = [byte[]]@() }
    [IO.File]::WriteAllBytes((Join-Path $output 'entry-default-unsigned.hap'), $bytes)
  }
}
& ${quote(nativeScript)} -ProjectRoot ${quote(directory)} -Task ${quote(task)}
exit 0
`);
  const result = spawnSync(powershell, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', wrapper], {
    encoding: 'utf8', timeout: 20000, env: { ...process.env, NATIVE_TEST_SCENARIO: scenario }
  });
  assert.ifError(result.error);
  let calls = '';
  try { calls = await readFile(callLog, 'utf8'); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  return { ...result, calls };
}

test('native driver installs both scopes, lints and builds in order', async t => {
  const result = await runNative(t);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls.trim().split(/\r?\n/).map(line => line.split(' ')[0]), ['ohpm', 'ohpm', 'codelinter', 'hvigorw', 'hvigorw']);
  assert.match(result.calls, /--format json/);
  assert.match(result.calls, /assembleHap/);
});

test('warning-only Code Linter reports remain visible without blocking compilation', async t => {
  const result = await runNative(t, 'warning-report');
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /0 error\(s\), 1 warning\(s\)/);
  assert.match(result.calls, /assembleHap/);
});

for (const scenario of ['install-error', 'lint-error', 'missing-report', 'invalid-report', 'schema-error', 'error-report', 'unknown-severity', 'tool-diagnostic-error', 'build-error', 'missing-hap', 'empty-hap']) {
  test(`native driver rejects ${scenario}`, async t => {
    const result = await runNative(t, scenario);
    assert.notEqual(result.status, 0, result.stdout);
    if (scenario === 'error-report') assert.match(result.stderr, /error-level findings/);
    if (scenario === 'unknown-severity') assert.match(result.stderr, /Unknown Code Linter diagnostic severity/);
    if (scenario === 'install-error') assert.doesNotMatch(result.calls, /codelinter|hvigorw/);
    if (['lint-error', 'missing-report', 'invalid-report', 'schema-error', 'error-report', 'unknown-severity', 'tool-diagnostic-error'].includes(scenario)) assert.doesNotMatch(result.calls, /hvigorw/);
  });
}

test('a corrupt SDK download is rejected before extraction or tool execution', async t => {
  const parent = await realpath(tmpdir());
  const directory = await mkdtemp(path.join(parent, 'library-hm-sdk-'));
  t.after(async () => {
    const resolved = path.resolve(directory);
    if (path.dirname(resolved) !== parent || !path.basename(resolved).startsWith('library-hm-sdk-')) throw new Error('Unexpected SDK fixture path');
    await rm(resolved, { recursive: true, force: true });
  });
  const tools = path.join(directory, 'tools'); await mkdir(tools);
  const scripts = {
    uname: '#!/bin/bash\nif [[ "$1" == -s ]]; then echo Linux; else echo x86_64; fi\n',
    curl: '#!/bin/bash\nwhile [[ $# -gt 0 ]]; do\n  if [[ "$1" == --output ]]; then printf "synthetic corrupt SDK" > "$2"; exit 0; fi\n  shift\ndone\nexit 2\n',
    unzip: '#!/bin/bash\nprintf "extraction attempted" > "$SDK_EXTRACTION_MARKER"\n'
  };
  for (const [name, source] of Object.entries(scripts)) {
    const file = path.join(tools, name); await writeFile(file, source); await chmod(file, 0o755);
  }
  const marker = path.join(directory, 'extraction-marker');
  const bash = process.platform === 'win32'
    ? path.resolve(execFileSync('git', ['--exec-path'], { encoding: 'utf8' }).trim(), '../../../bin/bash.exe')
    : 'bash';
  const posix = value => value.replaceAll('\\', '/');
  const result = spawnSync(bash, ['--noprofile', '--norc', '-c', 'export PATH="$1:$PATH"\nexec bash scripts/ci/setup-harmony.sh', 'sdk-fixture', posix(tools)], {
    encoding: 'utf8', timeout: 15000,
    env: { ...process.env, RUNNER_TEMP: posix(directory), GITHUB_PATH: posix(path.join(directory, 'github-path')), GITHUB_ENV: posix(path.join(directory, 'github-env')), SDK_EXTRACTION_MARKER: posix(marker) }
  });
  assert.ifError(result.error);
  assert.notEqual(result.status, 0, result.stdout);
  await assert.rejects(access(marker), { code: 'ENOENT' });
  await assert.rejects(access(path.join(directory, 'github-path')), { code: 'ENOENT' });
});
