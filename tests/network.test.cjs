const { test } = require('node:test');

const assert = require('node:assert/strict');

const fs = require('node:fs');

const path = require('node:path');

const vm = require('node:vm');

const ts = require('typescript');

const output = path.join(process.cwd(), '.local/ci/logic/dist');

const load = file => require(path.join(output, file));

const { HttpClient } = load('core/network/HttpClient.js');

const { HttpConfig, HttpMethod, HttpParameter, HttpResponse, HttpResponseType } = load('core/network/HttpTypes.js');

const { HttpError, HttpErrorCode } = load('core/network/HttpError.js');

const { CancellationToken } = load('core/network/CancellationToken.js');

const origin = 'https://example.invalid';

const json = data => new HttpResponse(200, JSON.stringify(data));

const book = (id = 1, hash = 'hash-a') => ({ id, hash, title: `Book ${id}`, author: 'Author', extension: 'epub' });

function client(handler, base = origin) {
  const calls = []; const config = new HttpConfig(); config.baseUrl = base;
  const transport = { send: async (request, token) => { calls.push(request); return handler(request, token); } };
  return { calls, config, http: new HttpClient(transport, config), transport };
}

// Compiles the real SDK adapter source, injecting only SDK test doubles. Native compilation remains required.
function native(relative, kits) {
  const source = fs.readFileSync(path.join('entry/src/main/ets', relative), 'utf8');
  const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.CommonJS } }).outputText;
  const module = { exports: {} };
  vm.runInNewContext(js, { module, exports: module.exports, ArrayBuffer, Uint8Array, Map,
    require: name => kits[name] ?? require(path.resolve(output, path.dirname(relative), name)) });
  return module.exports;
}

function nativeHttp(handler) {
  const tasks = [];
  const kit = { RequestMethod: HttpMethod, HttpDataType: { STRING: 0, ARRAY_BUFFER: 1 }, createHttp() {
    const task = { destroyed: 0, request(url, options) { return handler(url, options); }, destroy() { this.destroyed++; } };
    tasks.push(task); return task;
  } };
  const { HarmonyHttpTransport } = native('platform/network/HarmonyHttpTransport.ets', { '@kit.NetworkKit': { http: kit } });
  return { tasks, kit, transport: new HarmonyHttpTransport() };
}

test('HTTP encodes repeated query/form keys, JSON bodies and merges headers without mutating defaults', async () => {
  const c = client(async () => json({ success: 1 }));
  await c.http.get('/search?old=1', { query: [new HttpParameter('q', '中文 & +'), new HttpParameter('tag[]', 'a'), new HttpParameter('tag[]', 'b')],
    headers: { Accept: 'text/plain', 'X-Request': 'one' } });
  assert.equal(c.calls[0].url, origin + '/search?old=1&q=%E4%B8%AD%E6%96%87%20%26%20%2B&tag%5B%5D=a&tag%5B%5D=b');
  assert.equal(c.calls[0].headers.accept, 'text/plain');
  await c.http.postForm('login', [new HttpParameter('email', 'a+b@example.invalid'), new HttpParameter('password', 'a & b')]);
  assert.equal(c.calls[1].body, 'email=a%2Bb%40example.invalid&password=a+%26+b');
  assert.match(c.calls[1].headers['content-type'], /x-www-form-urlencoded/);
  assert.equal(c.calls[1].headers['x-request'], undefined); assert.equal(c.config.headers.accept, 'application/json');
  await c.http.postJson('/json', { title: '中文' });
  assert.equal(c.calls[2].body, JSON.stringify({ title: '中文' }));
  assert.match(c.calls[2].headers['content-type'], /application\/json/);
});

test('HTTP rejects insecure/cross-origin URLs, header injection, invalid timeouts and GET bodies before sending', async () => {
  const c = client(async () => json({}));
  for (const target of ['http://example.invalid', '//evil.invalid/a', 'https://evil.invalid/a', '/a#fragment', '/a\\b']) {
    await assert.rejects(c.http.get(target), { code: HttpErrorCode.InvalidRequest });
  }
  await assert.rejects(c.http.get('/a', { headers: { Test: 'x\r\ny' } }), { code: HttpErrorCode.InvalidRequest });
  await assert.rejects(c.http.get('/a', { connectTimeoutMs: 0 }), { code: HttpErrorCode.InvalidRequest });
  await assert.rejects(c.http.request(HttpMethod.GET, '/a', {}, 'body'), { code: HttpErrorCode.InvalidRequest });
  assert.equal(c.calls.length, 0);
});

test('HTTP status, malformed JSON and transport errors are distinct and do not echo sensitive bodies', async () => {
  await assert.rejects(client(async () => new HttpResponse(504, 'synthetic-sensitive-body')).http.get('/a'), error =>
    error.code === HttpErrorCode.Status && error.status === 504 && !JSON.stringify(error).includes('synthetic-sensitive-body'));
  await assert.rejects(client(async () => { throw new Error('synthetic-secret'); }).http.get('/a'), error =>
    error.code === HttpErrorCode.Network && !error.message.includes('synthetic-secret'));
  const result = await client(async () => new HttpResponse(200, '<html>challenge</html>')).http.get('/a');
  assert.throws(() => result.json(), { code: HttpErrorCode.InvalidJson });
  const empty = await client(async () => new HttpResponse(204, '')).http.get('/a'); assert.equal(empty.text(), '');
});

test('native HTTP creates one handle per request, sets timeouts/cache/body and releases completed handles', async () => {
  const seen = [];
  const n = nativeHttp(async (url, options) => { seen.push({ url, options });
    return { responseCode: 200, result: 'ok', header: {}, cookies: '' }; });
  const config = new HttpConfig(); config.baseUrl = origin;
  const http = new HttpClient(n.transport, config);
  await http.get('/one', { connectTimeoutMs: 500, readTimeoutMs: 900 });
  await http.postForm('/two', [new HttpParameter('x', 'y')]);
  assert.deepEqual(n.tasks.map(t => t.destroyed), [1, 1]);
  assert.equal(seen[0].options.usingCache, false); assert.equal(seen[0].options.connectTimeout, 500);
  assert.equal(seen[0].options.readTimeout, 900); assert.equal(seen[1].options.extraData, 'x=y');
});

test('native cancellation is immediate, idempotent and releases resources even if the SDK responds late', async () => {
  let finish; const n = nativeHttp(() => new Promise(resolve => { finish = resolve; }));
  const config = new HttpConfig(); config.baseUrl = origin;
  const http = new HttpClient(n.transport, config), token = new CancellationToken();
  const pending = http.get('/pending', { cancellation: token });
  token.cancel(); token.cancel();
  await assert.rejects(pending, { code: HttpErrorCode.Cancelled });
  assert.equal(n.tasks[0].destroyed, 1);
  finish({ responseCode: 200, result: 'late', header: {}, cookies: '' });
  await Promise.resolve(); assert.equal(n.tasks[0].destroyed, 1);
  const before = new CancellationToken(); before.cancel();
  await assert.rejects(http.get('/never', { cancellation: before }), { code: HttpErrorCode.Cancelled });
  assert.equal(n.tasks.length, 1);
});

test('native timeout, TLS failures and synchronous exceptions are sanitized and destroy their handles', async () => {
  for (const code of [2300028, 2300060]) {
    const n = nativeHttp(async () => { throw { code, message: 'synthetic-secret' }; });
    const config = new HttpConfig(); config.baseUrl = origin;
    await assert.rejects(new HttpClient(n.transport, config).get('/a'), error =>
      error.code === (code === 2300028 ? HttpErrorCode.Timeout : HttpErrorCode.Network) &&
      error.nativeCode === code && !error.message.includes('synthetic-secret'));
    assert.equal(n.tasks[0].destroyed, 1);
  }
  const n = nativeHttp(() => { throw new Error('synthetic-secret'); });
  const config = new HttpConfig(); config.baseUrl = origin;
  await assert.rejects(new HttpClient(n.transport, config).get('/a'), { code: HttpErrorCode.Network });
  assert.equal(n.tasks[0].destroyed, 1);
});

test('binary responses keep their bytes and an unexpected text body cannot masquerade as a file', async () => {
  let raw = new Uint8Array([1, 2, 3]).buffer;
  const n = nativeHttp(async (_url, options) => {
    assert.equal(options.expectDataType, 1);
    return { responseCode: 200, result: raw, header: {}, cookies: '' };
  });
  const config = new HttpConfig(); config.baseUrl = origin;
  const http = new HttpClient(n.transport, config);
  assert.deepEqual(new Uint8Array((await http.get('/bytes', { responseType: HttpResponseType.Binary })).body), new Uint8Array([1, 2, 3]));
  raw = '<html>challenge</html>';
  await assert.rejects(http.get('/challenge', { responseType: HttpResponseType.Binary }), { code: HttpErrorCode.InvalidResponse });
  assert.deepEqual(n.tasks.map(task => task.destroyed), [1, 1]);
});
