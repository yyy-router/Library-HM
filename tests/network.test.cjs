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
const { MemorySessionVault } = load('core/security/SessionVault.js');
const { AppContainer } = load('app/AppContainer.js');
const { AccountSession } = load('domain/model/AccountSession.js');
const { EapiSessionStore } = load('data/remote/EapiSessionStore.js');
const { HttpCoverImageRepository } = load('data/remote/HttpCoverImageRepository.js');
const { Book, BookFormat } = load('domain/model/Book.js');
const { RemoteBookSource } = load('domain/model/RemoteBookSource.js');
const { readBookText } = load('data/remote/EapiTypes.js');
const origin = 'https://example.invalid';
const json = data => new HttpResponse(200, JSON.stringify(data));
const book = (id = 1, hash = 'hash-a') => ({ id, hash, title: `Book ${id}`, author: 'Author', extension: 'epub' });
function deferred() {
  let resolve, reject;
  const promise = new Promise((success, failure) => { resolve = success; reject = failure; });
  return { promise, resolve, reject };
}
function client(handler, base = origin) {
  const calls = []; const config = new HttpConfig(); config.baseUrl = base;
  const transport = { send: async (request, token) => { calls.push(request); return handler(request, token); } };
  return { calls, config, http: new HttpClient(transport, config), transport };
}

const detailBook = (id = '1', hash = 'hash-a', base = origin) => new Book(`remote:${id}:${hash}`,
  `Book ${id}`, 'List author', BookFormat.Unknown, '', '', false, '', 0.75, '', undefined,
  new RemoteBookSource(base, id, hash, 'https://covers.example.invalid/list.jpg'));

test('anonymous details enrich sparse list metadata and preserve the selected identity without requesting a file', async () => {
  const calls = [];
  const selected = detailBook();
  const app = new AppContainer({ send: async request => {
    calls.push(request);
    return json({ success: 1, book: { id: 1, hash: 'hash-a', title: 'Title &amp; subtitle',
      authors: [{ name: 'Author &amp; Co' }], description: '<p>Full introduction: 1 &lt; 2.</p><p>Second paragraph.</p>',
      publisher: 'Press &amp; Co', year: 2024, language: '中文', pages: '320', edition: 2,
      identifier: '9780000000000, B012345678', extension: 'pdf', filesize: 2097152, cover: '/covers/detail.jpg' } });
  } }, origin);
  const details = await app.catalog.getDetails(selected);
  assert.equal(details.book.id, selected.id);
  assert.equal(details.book.title, 'Title & subtitle');
  assert.equal(details.book.author, 'Author & Co');
  assert.equal(details.book.description, 'Full introduction: 1 < 2. Second paragraph.');
  assert.equal(details.publisher, 'Press & Co'); assert.equal(details.year, '2024');
  assert.equal(details.pages, '320'); assert.equal(details.edition, '2');
  assert.equal(details.language, '中文'); assert.equal(details.fileSize, '2.0 MB');
  assert.equal(details.identifier, '9780000000000, B012345678');
  assert.equal(details.book.formatLabel, 'PDF'); assert.equal(details.book.hasLocalFile(), false);
  assert.equal(details.book.source.coverUrl, origin + '/covers/detail.jpg');
  assert.equal(selected.formatLabel, ''); assert.equal(selected.description, '');
  assert.equal(calls.length, 1); assert.equal(calls[0].url, origin + '/eapi/book/1/hash-a');
  assert.equal(calls[0].connectTimeoutMs, 30000); assert.equal(calls[0].readTimeoutMs, 60000);
  assert.equal(calls[0].headers['remix-userkey'], undefined); assert.equal(calls[0].headers.cookie, undefined);
});

test('authenticated details use the existing session; absent optional fields stay empty', async () => {
  let response = { title: 'Only required detail metadata' };
  const calls = [];
  const app = new AppContainer({ send: async request => { calls.push(request); return json({ success: 1, book: response }); } }, origin);
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  const selected = detailBook();
  const details = await app.catalog.getDetails(selected);
  for (const field of ['publisher', 'year', 'language', 'pages', 'edition', 'identifier', 'fileSize']) assert.equal(details[field], '');
  assert.equal(details.book.source.hash, 'hash-a'); assert.equal(details.book.formatLabel, '');
  assert.equal(details.book.author, selected.author); assert.equal(details.book.source.coverUrl, selected.source.coverUrl);
  assert.equal(calls[0].headers['remix-userkey'], 'synthetic-key');
  response = { title: 'Typed values', year: null, pages: {}, filesize: 'invalid', identifier: [], isbn: '9780000000000' };
  const typed = await app.catalog.getDetails(selected);
  assert.equal(typed.year, ''); assert.equal(typed.pages, ''); assert.equal(typed.fileSize, '');
  assert.equal(typed.identifier, '9780000000000');
  response = { title: 'Human-readable size', filesizeString: '3.4 MB', filesize: 1 };
  assert.equal((await app.catalog.getDetails(selected)).fileSize, '3.4 MB');
});

test('details reject missing or mismatched books and never request a different origin or missing hash', async () => {
  let payload; let calls = 0;
  const app = new AppContainer({ send: async () => { calls++; return json({ success: 1, book: payload }); } }, origin);
  for (const invalid of [undefined, null, [], {}, { id: 1 }, { title: 'Wrong book', id: 2 },
    { title: 'Wrong hash', id: 1, hash: 'different' }]) {
    payload = invalid;
    await assert.rejects(app.catalog.getDetails(detailBook()), { code: 'INVALID_RESPONSE' });
  }
  const before = calls;
  await assert.rejects(app.catalog.getDetails(detailBook('1', '')), { code: 'INVALID_BOOK_SOURCE' });
  await assert.rejects(app.catalog.getDetails(detailBook('1', 'hash-a', 'https://other.example.invalid')), { code: 'INVALID_BOOK_SOURCE' });
  assert.equal(calls, before);
});

test('anonymous details distinguish a login requirement and cannot invalidate a newly published session', async () => {
  const pending = deferred(), started = deferred();
  let response = json({ success: 0, error: 'Please login' });
  const app = new AppContainer({ send: async () => response }, origin);
  await assert.rejects(app.catalog.getDetails(detailBook()), { code: 'AUTH_REQUIRED' });
  assert.equal(app.api.sessions.display, undefined);
  const race = new AppContainer({ send: async () => { started.resolve(); return pending.promise; } }, origin);
  const request = race.catalog.getDetails(detailBook());
  await started.promise;
  await race.api.sessions.set('43', 'synthetic-new-key', new AccountSession('43', 'New reader'));
  pending.resolve(new HttpResponse(401, ''));
  await assert.rejects(request, { code: 'REQUEST_SUPERSEDED' });
  assert.equal(race.api.sessions.display.accountId, '43');
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  response = json({ success: 0, error: 'Invalid credentials' });
  await assert.rejects(app.catalog.getDetails(detailBook()), { code: 'AUTH_REQUIRED' });
  assert.equal(app.api.sessions.display, undefined);
});

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

test('anonymous popular catalog preserves sparse metadata without credentials; recommendations still require login', async () => {
  const calls = [];
  const app = new AppContainer({ send: async request => {
    calls.push(request);
    return json({ success: 1, books: [{ id: 7, title: 'Sparse book', hash: 'aa', cover: '//covers.example.invalid/7.jpg' },
      { id: 8, title: 'Other format', extension: 'mobi', url: '/book/8/bb/name' },
      { id: 9, title: 'No download identifier' }, { id: 7, title: 'Duplicate' }] });
  } }, origin);
  const books = await app.catalog.getPopular();
  assert.deepEqual(books.map(value => value.source.id), ['7', '8', '9']);
  assert.equal(books[0].format, BookFormat.Unknown);
  assert.equal(books[0].formatLabel, '');
  assert.equal(books[0].source.coverUrl, 'https://covers.example.invalid/7.jpg');
  assert.equal(books[1].formatLabel, 'MOBI'); assert.equal(books[1].source.hash, 'bb');
  assert.throws(() => app.api.bookPath(books[2]), { code: 'INVALID_BOOK_SOURCE' });
  await assert.rejects(app.catalog.getRecommended(), { code: 'AUTH_REQUIRED' });
  assert.equal(calls.length, 1); assert.equal(calls[0].url, origin + '/eapi/book/most-popular');
  assert.equal(calls[0].headers['remix-userkey'], undefined); assert.equal(calls[0].headers.cookie, undefined);
});

test('catalog display decodes HTML entities, strips description markup and preserves valid Unicode', () => {
  assert.equal(readBookText('Author &amp; Author'), 'Author & Author');
  assert.equal(readBookText('&lt;p&gt;Text&nbsp;&amp;amp; more&lt;/p&gt;<p>Next</p>', true), 'Text & more Next');
  assert.equal(readBookText('&#20013;&#x6587; &#x1F4DA;'), '中文 📚');
  assert.equal(readBookText('&#x110000; &#55296; &unknown;'), '&#x110000; &#55296; &unknown;');
  assert.equal(readBookText('A &lt; B'), 'A < B');
  assert.equal(readBookText('1 &lt; 2 and 3 &gt; 2', true), '1 < 2 and 3 > 2');
  assert.equal(readBookText('x<y && z>w; 1<2; 3>2', true), 'x<y && z>w; 1<2; 3>2');
  assert.equal(readBookText('<p class="lead">Math: 1 &lt; 2</p><br/><span data-label="a > b">3 &gt; 2</span>', true),
    'Math: 1 < 2 3 > 2');
  assert.equal(readBookText('Before<!-- comment --><strong>after</strong>', true), 'Before after');
});

test('catalog differentiates truly empty lists from malformed nonempty responses and keeps sparse recommendations', async () => {
  let payload = [];
  const vault = new MemorySessionVault();
  const app = new AppContainer({ send: async () => json({ success: 1, books: payload }) }, origin, vault);
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  assert.deepEqual(await app.catalog.getRecommended(), []);
  payload = [{ id: 4, title: 'Only required metadata' }];
  assert.equal((await app.catalog.getRecommended()).length, 1);
  payload = [{ hash: 'aa' }, null, 'unexpected'];
  await assert.rejects(app.catalog.getRecommended(), { code: 'INVALID_RESPONSE' });
  payload = undefined;
  await assert.rejects(app.catalog.getRecommended(), { code: 'INVALID_RESPONSE' });
});

const pngBytes = () => new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]).buffer;
const encoder = { encode: (bytes, mime) => `data:${mime};base64,${Buffer.from(bytes).toString('base64')}` };

test('cover fetching shares HTTP transport, never forwards API credentials, deduplicates requests and caches successes', async () => {
  const calls = []; let complete;
  const app = new AppContainer({ send: request => {
    calls.push(request); return new Promise(resolve => { complete = resolve; });
  } }, origin, new MemorySessionVault(), encoder);
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  const url = 'https://covers.example.invalid/a.png';
  const first = app.covers.load(url), second = app.covers.load(url);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].headers['remix-userkey'], undefined); assert.equal(calls[0].headers.cookie, undefined);
  assert.equal(calls[0].headers.source, undefined);
  assert.equal(calls[0].responseType, HttpResponseType.Binary);
  assert.equal(calls[0].maxResponseBytes, 1024 * 1024);
  complete(new HttpResponse(200, pngBytes()));
  assert.equal(await first, await second); assert.equal(await first, await app.covers.load(url));
  assert.equal(calls.length, 1);
});

test('cover errors remain retryable and HTML/challenge/oversized images are rejected before display', async () => {
  let body = new TextEncoder().encode('<html>challenge</html>').buffer;
  const c = client(async () => new HttpResponse(200, body), '');
  const covers = new HttpCoverImageRepository(c.http, encoder);
  const url = 'https://covers.example.invalid/book';
  await assert.rejects(covers.load(url), { code: 'INVALID_COVER' });
  body = pngBytes(); assert.match(await covers.load(url), /^data:image\/png;base64,/);
  assert.equal(c.calls.length, 2);
  body = new ArrayBuffer(1024 * 1024 + 1);
  await assert.rejects(covers.load(url + '/large'), { code: 'INVALID_COVER' });
  await assert.rejects(covers.load('http://covers.example.invalid/a'), { code: 'INVALID_COVER' });
  await assert.rejects(covers.load('https://name:password@covers.example.invalid/a'), { code: 'INVALID_COVER' });
});

test('cover cache evicts old entries and native encoder preserves image bytes', async () => {
  const c = client(async () => new HttpResponse(200, pngBytes()), '');
  const covers = new HttpCoverImageRepository(c.http, encoder);
  for (let index = 0; index < 25; index++) await covers.load(`https://covers.example.invalid/${index}`);
  await covers.load('https://covers.example.invalid/0');
  assert.equal(c.calls.length, 26);
  const { HarmonyImageSourceEncoder } = native('platform/network/HarmonyImageSourceEncoder.ets', {
    '@kit.ArkTS': { util: { Base64Helper: class { encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64'); } } } }
  });
  const bytes = new Uint8Array(pngBytes());
  assert.equal(new HarmonyImageSourceEncoder().encode(bytes, 'image/png'), encoder.encode(bytes, 'image/png'));
});

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

test('production repositories share real HTTP login/profile/search/recommendation/detail/file-link requests', async () => {
  const calls = [], vault = new MemorySessionVault();
  const app = new AppContainer({ send: async request => {
    calls.push(request);
    if (request.url.endsWith('/rpc.php')) return json({ errors: [], response: { user_id: 42, user_key: 'synthetic-key' } });
    if (request.url.endsWith('/profile')) return json({ success: 1, user: { id: 42, name: 'Reader', downloads_limit: 10, downloads_today: 3 } });
    if (request.url.endsWith('/file')) return json({ success: 1, file: { downloadLink: 'https://files.example.invalid/book.epub' } });
    if (/\/eapi\/book\/1\//.test(request.url)) return json({ success: 1, book: book() });
    return json({ success: 1, books: [book()] });
  } }, origin, vault);
  assert.deepEqual(await app.bookshelf.listBooks(), []);
  assert.equal(await app.account.getSession(), undefined); assert.equal(calls.length, 0);
  const session = await app.account.signIn('reader@example.invalid', 'synthetic-password');
  assert.equal(session.displayName, 'Reader'); assert.equal(session.remainingDownloads, 7);
  assert.ok(!JSON.stringify(session).includes('synthetic-key'));
  assert.ok(!(await vault.read()).includes('synthetic-password'));
  const results = await app.catalog.search('中文'); const recommended = await app.catalog.getRecommended();
  assert.equal(results[0].isDemo, false); assert.equal(results[0].source.id, '1');
  assert.equal(results[0].asBookmark().source.hash, 'hash-a'); assert.equal(results[0].hasLocalFile(), false);
  assert.equal(recommended[0].id, results[0].id);
  await app.api.getBookDetails(results[0]);
  assert.equal(await app.api.getDownloadLink(results[0]), 'https://files.example.invalid/book.epub');
  const detailRequest = calls.find(request => request.url.endsWith('/eapi/book/1/hash-a'));
  assert.equal(detailRequest.connectTimeoutMs, 30000); assert.equal(detailRequest.readTimeoutMs, 60000);
  const searchRequest = calls.find(request => request.url.endsWith('/search'));
  assert.equal(searchRequest.connectTimeoutMs, 10000); assert.equal(searchRequest.readTimeoutMs, 30000);
  assert.equal(calls[0].headers['remix-userkey'], undefined);
  assert.ok(calls.slice(1).every(request => request.headers['remix-userkey'] === 'synthetic-key'));
  assert.ok(calls.every(request => request.headers.source === 'android'));
  assert.match(calls.find(r => r.url.endsWith('/search')).body, /extensions%5B%5D=epub&extensions%5B%5D=pdf/);
  await app.bookshelf.addBook(results[0].asBookmark()); await app.account.signOut();
  assert.equal((await app.bookshelf.listBooks()).length, 1); assert.equal(await vault.read(), undefined);
});

test('saved sessions restore and validate on startup; temporary network failures retain the vault', async () => {
  const vault = new MemorySessionVault();
  const initial = new EapiSessionStore(vault, origin);
  await initial.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  const app = new AppContainer({ send: async () => { throw new HttpError(HttpErrorCode.Timeout); } }, origin, vault);
  await assert.rejects(app.account.getSession(), { code: HttpErrorCode.Timeout });
  assert.ok(await vault.read());
  const restored = new AppContainer({ send: async () => json({ success: 1, user: { id: 42, name: 'Restored' } }) }, origin, vault);
  assert.equal((await restored.account.getSession()).displayName, 'Restored');
  assert.equal((await restored.account.getSession()).remainingDownloads, undefined);
});

test('missing/invalid credentials, HTTP auth failure and business failure never fabricate authentication or recommendations', async () => {
  const vault = new MemorySessionVault(); let response = json({ errors: [], response: {} });
  const app = new AppContainer({ send: async () => response }, origin, vault);
  await assert.rejects(app.catalog.search('query'), { code: 'AUTH_REQUIRED' });
  await assert.rejects(app.account.signIn('x@example.invalid', 'synthetic-password'), { code: 'LOGIN_FAILED' });
  assert.equal(await vault.read(), undefined);
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  response = json({ success: 0, error: 'Please login' });
  await assert.rejects(app.catalog.getRecommended(), { code: 'AUTH_REQUIRED' });
  assert.equal(await vault.read(), undefined);
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  response = new HttpResponse(401, 'sensitive');
  await assert.rejects(app.account.getSession(), { code: 'AUTH_REQUIRED' });
  assert.equal(await vault.read(), undefined);
});

test('sessions are origin-bound and logout wins over a pending credential save', async () => {
  const vault = new MemorySessionVault();
  await new EapiSessionStore(vault, origin).set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  const other = new EapiSessionStore(vault, 'https://other.example.invalid');
  await other.restore(); assert.equal(other.display, undefined); assert.equal(await vault.read(), undefined);
  let finish;
  const slow = { read: async () => undefined, write: () => new Promise(resolve => { finish = resolve; }), clear: () => vault.clear() };
  const sessions = new EapiSessionStore(slow, origin);
  const save = sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  const rejected = assert.rejects(save, { code: 'REQUEST_SUPERSEDED' });
  await Promise.resolve(); const logout = sessions.clear(); finish();
  await rejected; await logout; assert.equal(sessions.display, undefined);
});

test('403 with an explicit login error clears the vault while an HTML access challenge preserves it', async () => {
  const vault = new MemorySessionVault();
  let response = new HttpResponse(403, '<html>access challenge</html>');
  const app = new AppContainer({ send: async () => response }, origin, vault);
  await app.api.sessions.set('42', 'synthetic-key', new AccountSession('42', 'Reader'));
  await assert.rejects(app.catalog.getRecommended(), { code: HttpErrorCode.Status, status: 403 });
  assert.ok(await vault.read());
  response = new HttpResponse(403, JSON.stringify({ success: 0, error: 'Please login' }));
  await assert.rejects(app.catalog.getRecommended(), { code: 'AUTH_REQUIRED' });
  assert.equal(await vault.read(), undefined);
});

test('a stale auth failure cannot erase a newer account session', async () => {
  let fail;
  const vault = new MemorySessionVault();
  const app = new AppContainer({ send: () => new Promise((_resolve, reject) => { fail = reject; }) }, origin, vault);
  await app.api.sessions.set('42', 'synthetic-old-key', new AccountSession('42', 'Old'));
  const pending = app.api.get('/eapi/user/profile');
  await Promise.resolve(); await Promise.resolve();
  await app.api.sessions.set('43', 'synthetic-new-key', new AccountSession('43', 'New'));
  fail(new HttpError(HttpErrorCode.Status, 401));
  await assert.rejects(pending, { status: 401 });
  assert.equal(app.api.sessions.display.accountId, '43');
  assert.ok((await vault.read()).includes('synthetic-new-key'));
});

test('requests started during a credential write cannot invalidate the newly published session', async () => {
  for (const reply of ['http401', 'business403', 'transport401']) {
    let stored, holdWrite = false;
    const writeStarted = deferred(), writeRelease = deferred(), requestStarted = deferred(), response = deferred();
    const vault = { read: async () => stored, clear: async () => { stored = undefined; },
      write: async value => { if (holdWrite) { writeStarted.resolve(); await writeRelease.promise; } stored = value; } };
    const app = new AppContainer({ send: request => {
      assert.equal(request.headers['remix-userid'], '42');
      requestStarted.resolve(); return response.promise;
    } }, origin, vault);
    await app.api.sessions.set('42', 'synthetic-old-key', new AccountSession('42', 'Old'));
    const oldVersion = app.api.sessions.version;
    holdWrite = true;
    const saving = app.api.sessions.set('43', 'synthetic-new-key', new AccountSession('43', 'New'));
    await writeStarted.promise;
    assert.equal(app.api.sessions.version, oldVersion);
    const request = app.api.get('/eapi/user/profile');
    await requestStarted.promise;
    writeRelease.resolve(); await saving;
    assert.ok(app.api.sessions.version > oldVersion);
    assert.equal(app.api.sessions.display.accountId, '43');
    if (reply === 'http401') response.resolve(new HttpResponse(401, ''));
    else if (reply === 'business403') response.resolve(new HttpResponse(403, JSON.stringify({ success: 0, error: 'Please login' })));
    else response.reject(new HttpError(HttpErrorCode.Status, 401));
    await assert.rejects(request, { code: reply === 'transport401' ? HttpErrorCode.Status : 'REQUEST_SUPERSEDED' });
    assert.equal(app.api.sessions.display.accountId, '43');
    assert.equal(JSON.parse(stored).id, '43');
    assert.equal(app.api.sessions.headers()['remix-userkey'], 'synthetic-new-key');
  }
});

test('a pending credential write invalidates an earlier vault read before any credentials are published', async () => {
  const readStarted = deferred(), readRelease = deferred(), writeStarted = deferred(), writeRelease = deferred();
  let stored;
  const vault = { read: async () => { readStarted.resolve(); return readRelease.promise; }, clear: async () => { stored = undefined; },
    write: async value => { writeStarted.resolve(); await writeRelease.promise; stored = value; } };
  const sessions = new EapiSessionStore(vault, origin);
  const restoring = sessions.restore(); await readStarted.promise;
  const saving = sessions.set('43', 'synthetic-new-key', new AccountSession('43', 'New'));
  await writeStarted.promise;
  readRelease.resolve(JSON.stringify({ origin, id: '42', key: 'synthetic-old-key' })); await restoring;
  assert.equal(sessions.display, undefined);
  writeRelease.resolve(); await saving;
  assert.equal(sessions.display.accountId, '43'); assert.equal(JSON.parse(stored).id, '43');
});

test('a failed replacement write preserves the active credentials and their request revision', async () => {
  let stored, failWrite = false;
  const vault = { read: async () => stored, clear: async () => { stored = undefined; },
    write: async value => { if (failWrite) throw new Error('synthetic-write-failure'); stored = value; } };
  const sessions = new EapiSessionStore(vault, origin);
  await sessions.set('42', 'synthetic-old-key', new AccountSession('42', 'Old'));
  const version = sessions.version;
  failWrite = true;
  await assert.rejects(sessions.set('43', 'synthetic-new-key', new AccountSession('43', 'New')));
  assert.equal(sessions.version, version); assert.equal(sessions.display.accountId, '42');
  assert.equal(sessions.headers()['remix-userkey'], 'synthetic-old-key'); assert.equal(JSON.parse(stored).id, '42');
});

test('a failed secure save never reports a successful login, and malformed saved credentials are discarded', async () => {
  const vault = { read: async () => undefined, clear: async () => {},
    write: async () => { throw Object.assign(new Error('secure save failed'), { code: 'SESSION_STORAGE' }); } };
  const app = new AppContainer({ send: async () => json({ errors: [], response: { user_id: 42, user_key: 'synthetic-key' } }) }, origin, vault);
  await assert.rejects(app.account.signIn('reader@example.invalid', 'synthetic-password'), { code: 'SESSION_STORAGE' });
  assert.equal(app.api.sessions.display, undefined);
  const memory = new MemorySessionVault(); await memory.write('{broken');
  await new EapiSessionStore(memory, origin).restore(); assert.equal(await memory.read(), undefined);
});

test('ASSET adapter uses device-unlocked storage, updates existing assets and propagates sanitized storage errors', async () => {
  const Tag = { ALIAS: 1, SECRET: 2, ACCESSIBILITY: 3, RETURN_TYPE: 4 };
  let stored; let fail = false; let added;
  const asset = { Tag, ReturnType: { ALL: 0 }, Accessibility: { DEVICE_UNLOCKED: 2 },
    query: async () => { if (fail) throw { code: 24000005 }; return stored ? [new Map([[Tag.SECRET, stored]])] : []; },
    add: async values => { if (stored) throw { code: 24000003 }; added = values; stored = values.get(Tag.SECRET); },
    update: async (_query, values) => { stored = values.get(Tag.SECRET); }, remove: async () => { stored = undefined; } };
  const util = { TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } },
    TextDecoder: { create: () => ({ decodeToString: value => new TextDecoder('utf-8', { fatal: true }).decode(value) }) } };
  const { AssetSessionVault } = native('platform/security/AssetSessionVault.ets',
    { '@kit.AssetStoreKit': { asset }, '@kit.ArkTS': { util } });
  const vault = new AssetSessionVault();
  assert.equal(await vault.read(), undefined);
  await vault.write('synthetic-first'); assert.equal(added.get(Tag.ACCESSIBILITY), 2);
  await vault.write('synthetic-second'); assert.equal(await vault.read(), 'synthetic-second');
  fail = true; await assert.rejects(vault.read(), { code: 'SESSION_STORAGE' });
  fail = false; await vault.clear(); assert.equal(await vault.read(), undefined);
  await assert.rejects(vault.write('x'.repeat(1025)), { code: 'SESSION_STORAGE' });
});
