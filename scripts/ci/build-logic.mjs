import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import ts from 'typescript';
import { walk } from './check.mjs';

const root = process.cwd();
const output = path.resolve(root, '.local/ci/logic');
const expected = path.join(path.resolve(root), '.local', 'ci', 'logic');
if (output !== expected || !path.relative(root, output) || path.relative(root, output).startsWith('..')) throw new Error('Refusing to remove a directory outside the CI output directory');
// Only this checked workspace-local generated directory may be replaced.
await rm(output, { recursive: true, force: true });
await mkdir(path.join(output, 'src'), { recursive: true });
await writeFile(path.join(output, 'package.json'), '{"type":"commonjs"}\n');
const sourceRoot = path.join(root, 'entry/src/main/ets');
let count = 0;
for (const file of await walk(sourceRoot)) {
  const relative = path.relative(sourceRoot, file);
  const normalized = relative.split(path.sep).join('/');
  if (!file.endsWith('.ets') || !(/^(app|core|domain|data)\//.test(normalized) || normalized.endsWith('ViewModel.ets'))) continue;
  const source = await readFile(file, 'utf8');
  if (/@(?:Entry|Component)\b|from\s+['"]@(?:kit\/|ohos\.)/.test(source)) throw new Error(`${normalized}: SDK/UI code must not enter the pure-logic test build`);
  const destination = path.join(output, 'src', relative.replace(/\.ets$/, '.ts'));
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, source); count++;
}
await writeFile(path.join(output, 'src/arkui-test-globals.d.ts'), 'declare const Observed: ClassDecorator;\n');
const loaded = ts.readConfigFile(path.join(root, 'tsconfig.ci.json'), ts.sys.readFile);
if (loaded.error) throw new Error(ts.flattenDiagnosticMessageText(loaded.error.messageText, '\n'));
const parsed = ts.parseJsonConfigFileContent(loaded.config, ts.sys, root);
const program = ts.createProgram(parsed.fileNames, parsed.options);
const diagnostics = [...parsed.errors, ...ts.getPreEmitDiagnostics(program)];
if (diagnostics.length) {
  console.error(ts.formatDiagnosticsWithColorAndContext(diagnostics, { getCurrentDirectory: () => root, getCanonicalFileName: file => file, getNewLine: () => '\n' }));
  process.exitCode = 1;
} else {
  const result = program.emit();
  if (result.emitSkipped) throw new Error('Pure-logic TypeScript compilation did not emit test modules');
  console.log(`PASS Logic type check: ${count} source files compiled for isolated tests (not an ArkTS/ArkUI build)`);
}
