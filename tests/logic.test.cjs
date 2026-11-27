const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

// Only pure logic is exercised. This identity decorator does not emulate ArkUI reactivity.
globalThis.Observed = target => target;
const load = file => require(path.join(process.cwd(), '.local/ci/logic/dist', file));
const { Book, BookFormat } = load('domain/model/Book.js');
const { ReadingRecord } = load('domain/model/ReadingRecord.js');
const { DemoBookCatalogRepository, DemoBookshelfRepository, DemoAccountRepository } = load('data/demo/DemoRepositories.js');
const { DemoFileImporter } = load('data/demo/DemoFileImporter.js');
const { HomeViewModel } = load('features/home/HomeViewModel.js');
const { BookshelfViewModel } = load('features/bookshelf/BookshelfViewModel.js');
const { ReaderViewModel } = load('features/reader/ReaderViewModel.js');
const { RecommendationState } = load('features/home/HomeViewModel.js');
const { ShelfFilter, ShelfSort } = load('domain/model/ShelfEntry.js');
const { AccountSession } = load('domain/model/AccountSession.js');
const { LocalBookFile } = load('domain/model/LocalBookFile.js');
const { DownloadState } = load('domain/model/ShelfEntry.js');
const { UnavailableBookDownloader } = load('data/local/UnavailableBookDownloader.js');
const { AppError } = load('core/error/AppError.js');

// Explicit fixtures only: production AppContainer uses the real remote repositories.
function createDemoApp() {
  return { catalog: new DemoBookCatalogRepository(), bookshelf: new DemoBookshelfRepository(),
    account: new DemoAccountRepository(), importer: new DemoFileImporter(), downloader: new UnavailableBookDownloader() };
}

// These are adapter contract fixtures. They do not claim that Node wrote a HarmonyOS file.
const localFile = () => new LocalBookFile('file:///data/storage/el2/base/files/test.epub', 2048);

test('catalog searches title, author and format; empty query returns demo books', async () => {
  const catalog = new DemoBookCatalogRepository();
  assert.equal((await catalog.search('')).length, 12);
  assert.equal((await catalog.search('  pdf ')).length, 4);
  assert.equal((await catalog.search('指南')).length, 1);
  assert.equal((await catalog.search('林屿')).length, 1);
  assert.equal((await catalog.search('no-such-book')).length, 0);
});

test('bookshelf deduplicates IDs and returned list mutations do not alter storage', async () => {
  const shelf = new DemoBookshelfRepository(false);
  const book = new Book('test-book', '测试条目', '演示', BookFormat.EPUB, '');
  const original = (await shelf.listBooks()).length;
  await shelf.addBook(book); await shelf.addBook(book);
  const snapshot = await shelf.listBooks();
  assert.equal(snapshot.length, original + 1); assert.equal(snapshot[0].id, book.id);
  snapshot.pop();
  assert.equal((await shelf.listBooks()).length, original + 1);
});

test('history replaces a book record, sorts newest first and clamps progress', async () => {
  const shelf = new DemoBookshelfRepository(false);
  const [first, second] = await shelf.listBooks();
  await shelf.saveReadingRecord(new ReadingRecord(first, -1, 'demo:first', 10));
  await shelf.saveReadingRecord(new ReadingRecord(second, 0.5, 'demo:second', 20));
  await shelf.saveReadingRecord(new ReadingRecord(first, 2, 'demo:updated', 30));
  const history = await shelf.listHistory();
  assert.equal(history.length, 2); assert.equal(history[0].book.id, first.id);
  assert.equal(history[0].progress, 1); assert.equal(history[0].locator, 'demo:updated');
  assert.equal((await shelf.getReadingRecord(first.id)).progress, 1);
  assert.equal(await shelf.getReadingRecord('missing'), undefined);
  assert.equal((await new DemoBookshelfRepository(false).listHistory()).length, 0);
});

test('demo import generates unique demo records without pretending to have a local file', async () => {
  const importer = new DemoFileImporter();
  const first = await importer.importBook(), second = await importer.importBook();
  assert.notEqual(first.id, second.id); assert.equal(first.isDemo, true); assert.equal(first.localUri, '');
});

test('demo account never reports a fabricated authenticated session', async () => {
  const account = new DemoAccountRepository();
  assert.equal(await account.getSession(), undefined);
  await assert.rejects(account.signIn('demo@example.invalid', 'placeholder'), { code: 'NOT_IMPLEMENTED' });
  await account.signOut(); assert.equal(await account.getSession(), undefined);
});

test('home clears submitted password and restores busy state after rejected login', async () => {
  const app = createDemoApp(); const home = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  await home.signIn(); assert.equal(home.busy, false); assert.match(home.message, /填写/);
  home.email = 'demo@example.invalid'; home.password = 'placeholder'; await home.signIn();
  assert.equal(home.password, ''); assert.equal(home.busy, false); assert.equal(home.session, undefined);
  assert.match(home.message, /尚未接入/);
});

test('search failures release busy state and display an error instead of success', async () => {
  const app = createDemoApp();
  const catalog = { search: async () => { throw new Error('synthetic failure'); } };
  const home = new HomeViewModel(catalog, app.bookshelf, app.account);
  await home.search(); assert.equal(home.busy, false); assert.match(home.message, /失败/);
});

test('clearing search ignores late success and failure while a normal search still completes', async () => {
  const app = createDemoApp();
  const results = await app.catalog.search('指南');
  for (const rejectLate of [false, true]) {
    let resolve, reject;
    const response = new Promise((success, failure) => { resolve = success; reject = failure; });
    const home = new HomeViewModel({ search: () => response }, app.bookshelf, app.account);
    home.searched = true; home.keyword = 'pending';
    const pending = home.search();
    home.clearSearch();
    assert.equal(home.busy, false); assert.equal(home.searched, false);
    if (rejectLate) reject(new Error('synthetic late error')); else resolve(results);
    await pending;
    assert.equal(home.searched, false); assert.deepEqual(home.results, []);
    assert.equal(home.message, ''); assert.equal(home.keyword, ''); assert.equal(home.busy, false);
  }
  const normal = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  normal.keyword = '指南'; await normal.search();
  assert.equal(normal.searched, true); assert.deepEqual(normal.results, results);
});

test('a cleared search cannot overwrite or release the busy state of a newer search', async () => {
  const app = createDemoApp(); const finish = [];
  const home = new HomeViewModel({ search: () => new Promise(resolve => finish.push(resolve)) },
    app.bookshelf, app.account);
  home.keyword = 'old'; const old = home.search(); home.clearSearch();
  home.keyword = 'new'; const current = home.search();
  assert.equal(finish.length, 2);
  finish[0]([]); await old;
  assert.equal(home.busy, true); assert.equal(home.searched, false); assert.equal(home.keyword, 'new');
  const results = await app.catalog.search('指南');
  finish[1](results); await current;
  assert.equal(home.busy, false); assert.equal(home.searched, true); assert.deepEqual(home.results, results);
});

test('clearing search and old search completion do not unlock a pending account operation', async () => {
  const app = createDemoApp(); let finishSearch, finishLogin;
  const home = new HomeViewModel({ search: () => new Promise(resolve => { finishSearch = resolve; }),
    getRecommended: async () => [] },
    app.bookshelf, { signIn: () => new Promise(resolve => { finishLogin = resolve; }) });
  const old = home.search(); home.clearSearch();
  home.email = 'synthetic@example.invalid'; home.password = 'synthetic-password';
  const login = home.signIn();
  home.clearSearch(); assert.equal(home.busy, true);
  finishSearch([]); await old; assert.equal(home.busy, true);
  finishLogin(new AccountSession('synthetic-user', '测试读者'));
  await login; assert.equal(home.busy, false);
  assert.equal(home.session.accountId, 'synthetic-user');
});

test('cancelled and failed imports do not add records or leave the screen busy', async () => {
  const app = createDemoApp(); const count = (await app.bookshelf.listBooks()).length;
  const cancelled = new BookshelfViewModel(app.bookshelf, { importBook: async () => undefined }, app.downloader);
  await cancelled.importBook(); assert.equal(cancelled.busy, false);
  const failed = new BookshelfViewModel(app.bookshelf, { importBook: async () => { throw new Error('synthetic failure'); } }, app.downloader);
  await failed.importBook(); assert.equal(failed.busy, false); assert.match(failed.message, /失败/);
  assert.equal((await app.bookshelf.listBooks()).length, count);
});

test('explicit demo fixtures keep bookmarks and imports unreadable without real downloads', async () => {
  const app = createDemoApp();
  const home = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  const shelf = new BookshelfViewModel(app.bookshelf, app.importer, app.downloader);
  home.keyword = '指南'; await home.search(); await home.addToShelf(home.results[0]);
  await shelf.load(); assert.ok(shelf.books.some(book => book.id === home.results[0].id));
  await shelf.importBook(); const imported = shelf.books[0];
  await shelf.downloadBook(imported);
  assert.equal(shelf.entries.find(entry => entry.book.id === imported.id).download.state, DownloadState.Failed);
  assert.match(shelf.message, /尚未接入/);
  const reader = new ReaderViewModel(app.bookshelf);
  assert.equal(await reader.open(imported), false);
  reader.progress = 0.42; await reader.saveProgress();
  assert.equal(await app.bookshelf.getReadingRecord(imported.id), undefined);
});

test('guests load popular books and signed-in readers use only the recommendation endpoint', async () => {
  const app = createDemoApp();
  let calls = 0, popularCalls = 0;
  const catalog = {
    search: async () => { throw new Error('search must not supply recommendations'); },
    getRecommended: async () => { calls++; return []; },
    getPopular: async () => { popularCalls++; return []; }
  };
  const home = new HomeViewModel(catalog, app.bookshelf, app.account);
  await home.loadSession();
  assert.equal(calls, 0); assert.equal(popularCalls, 1);
  assert.equal(home.recommendationState, RecommendationState.Ready);
  home.session = new AccountSession('synthetic-user', '测试读者');
  await home.loadRecommendations();
  assert.equal(calls, 1); assert.equal(home.recommendationState, RecommendationState.Ready);
  assert.equal(popularCalls, 1);
  assert.deepEqual(home.recommendations, []);
  const unconfigured = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  unconfigured.session = home.session; await unconfigured.loadRecommendations();
  assert.equal(unconfigured.recommendationState, RecommendationState.Unconfigured);
  assert.deepEqual(unconfigured.recommendations, []);
});

test('recommendations preserve upstream order, clear stale data on failure and reset on logout', async () => {
  const app = createDemoApp();
  const source = (await app.catalog.search('')).slice(0, 3).reverse();
  let fail = false;
  const catalog = {
    search: async () => [],
    getRecommended: async () => { if (fail) throw new AppError('INVALID_RESPONSE', '测试：书目格式无效'); return source; },
    getPopular: async () => []
  };
  const home = new HomeViewModel(catalog, app.bookshelf, app.account);
  home.session = new AccountSession('synthetic-user', '测试读者');
  await home.loadRecommendations();
  assert.deepEqual(home.recommendations.map(book=>book.id), source.map(book=>book.id));
  fail = true; await home.loadRecommendations();
  assert.equal(home.recommendationState, RecommendationState.Error);
  assert.equal(home.recommendationMessage, '测试：书目格式无效');
  assert.deepEqual(home.recommendations, []);
  await home.signOut();
  assert.equal(home.recommendationState, RecommendationState.Ready);
  assert.deepEqual(home.recommendations, []);
});

test('logging out ignores a late recommendation response from the prior session', async () => {
  const app = createDemoApp();
  let resolveList;
  const response = new Promise(resolve => { resolveList = resolve; });
  const popular = (await app.catalog.search('')).slice(0, 1);
  const catalog = { search: async () => [], getRecommended: () => response, getPopular: async () => popular };
  const home = new HomeViewModel(catalog, app.bookshelf, app.account);
  home.session = new AccountSession('synthetic-user', '测试读者');
  const loading = home.loadRecommendations();
  await home.signOut();
  resolveList(await app.catalog.search('')); await loading;
  assert.equal(home.recommendationState, RecommendationState.Ready);
  assert.deepEqual(home.recommendations, popular);
});

test('logging in replaces popular books and ignores a late anonymous discovery response', async () => {
  const app = createDemoApp();
  const source = await app.catalog.search('');
  let resolvePopular;
  const catalog = { search: async () => [], getPopular: () => new Promise(resolve => { resolvePopular = resolve; }),
    getRecommended: async () => source.slice(1, 3) };
  const home = new HomeViewModel(catalog, app.bookshelf, {
    signIn: async () => new AccountSession('synthetic-user', '测试读者')
  });
  const pending = home.loadRecommendations();
  home.searched = true; home.results = source.slice(0, 1);
  home.email = 'reader@example.invalid'; home.password = 'synthetic-password';
  await home.signIn();
  resolvePopular(source.slice(0, 1)); await pending;
  assert.ok(home.session);
  assert.equal(home.searched, false); assert.deepEqual(home.results, []);
  assert.deepEqual(home.recommendations, source.slice(1, 3));
});

test('confirmed search authentication failure clears the account and loads public books without a stuck spinner', async () => {
  const app = createDemoApp(); const popular = (await app.catalog.search('')).slice(0, 2);
  const home = new HomeViewModel({ search: async () => { throw new AppError('AUTH_REQUIRED', '测试：登录失效'); },
    getRecommended: async () => [], getPopular: async () => popular }, app.bookshelf, app.account);
  home.session = new AccountSession('synthetic-user', '测试读者'); home.keyword = 'book';
  await home.search();
  assert.equal(home.session, undefined); assert.equal(home.busy, false);
  assert.equal(home.recommendationState, RecommendationState.Ready);
  assert.deepEqual(home.recommendations, popular); assert.match(home.message, /登录失效/);
});

test('bookshelf merges history once per book and applies reading filters, search and sort', async () => {
  const app = createDemoApp();
  const shelf = new BookshelfViewModel(app.bookshelf, app.importer, app.downloader);
  await shelf.load();
  assert.equal(shelf.entries.length, 8); assert.equal(shelf.readingCount, 4);
  assert.equal(new Set(shelf.entries.map(entry=>entry.book.id)).size, 8);
  assert.equal(shelf.lastReadBookId, shelf.history[0].book.id);
  shelf.setFilter(ShelfFilter.Reading);
  assert.equal(shelf.entries.length, 4);
  assert.ok(shelf.entries.every(entry=>entry.progress>0 && entry.progress<1));
  shelf.setFilter(ShelfFilter.Finished);
  assert.equal(shelf.entries.length, 1); assert.equal(shelf.entries[0].progress, 1);
  shelf.setFilter(ShelfFilter.All); shelf.setSort(ShelfSort.Progress);
  assert.equal(shelf.entries[0].progress, 1);
  shelf.setQuery('  林屿  '); assert.equal(shelf.entries.length, 1);
  assert.equal(shelf.entries[0].book.title, '山海之间');
  shelf.setQuery('missing-synthetic'); assert.equal(shelf.entries.length, 0);
  shelf.setQuery('');
  assert.deepEqual(shelf.rows(3).map(row=>row.entries.length), [3,3,2]);
  await shelf.importBook();
  assert.equal(shelf.filter, ShelfFilter.All); assert.equal(shelf.query, '');
  assert.equal(shelf.entries.length, 9);
});

test('local readiness requires non-demo verified file metadata, not a remote URL or bare URI', () => {
  for (const file of [new LocalBookFile('', 100), new LocalBookFile('https://example.invalid/book', 100),
    new LocalBookFile('//example.invalid/book', 100), new LocalBookFile('/', 100),
    new LocalBookFile('file://', 100), new LocalBookFile('/data/book', 0),
    new LocalBookFile('/data/book', NaN), new LocalBookFile('/data/book', Infinity)]) {
    assert.equal(file.isValid(), false);
  }
  const metadata = new Book('remote', '远程书目', '测试', BookFormat.EPUB, '', localFile().uri, false);
  assert.equal(metadata.hasLocalFile(), false);
  const ready = metadata.withLocalFile(localFile());
  assert.equal(ready.hasLocalFile(), true);
  assert.equal(ready.asBookmark().hasLocalFile(), false);
  assert.equal(ready.asBookmark().localUri, '');
});

test('home saves only bookmarks and adding an existing bookmark preserves its local file', async () => {
  const app = createDemoApp();
  const home = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  const incoming = new Book('remote-new', '新书目', '测试', BookFormat.EPUB, '').withLocalFile(localFile());
  await home.addToShelf(incoming);
  let book = (await app.bookshelf.listBooks()).find(book => book.id === incoming.id);
  assert.equal(book.hasLocalFile(), false);
  assert.match(home.message, /收藏/);
  await app.bookshelf.saveLocalFile(incoming.id, localFile());
  await home.addToShelf(incoming.asBookmark());
  book = (await app.bookshelf.listBooks()).find(book => book.id === incoming.id);
  assert.equal(book.hasLocalFile(), true);
});

test('a download stays unreadable until file registration completes and duplicate taps start one request', async () => {
  const app = createDemoApp();
  let finish, report, calls = 0;
  const downloader = { download: (_book, callback) => {
    calls++; report = callback; return new Promise(resolve => { finish = resolve; });
  } };
  const shelf = new BookshelfViewModel(app.bookshelf, app.importer, downloader);
  await shelf.load(); const book = shelf.books[0];
  const downloading = shelf.downloadBook(book);
  report(0.6);
  let entry = shelf.entries.find(entry => entry.book.id === book.id);
  assert.equal(entry.download.state, DownloadState.Downloading);
  assert.equal(entry.download.progress, 0.6); assert.equal(entry.book.hasLocalFile(), false);
  assert.equal(await new ReaderViewModel(app.bookshelf).open(entry.book), false);
  await shelf.downloadBook(book); assert.equal(calls, 1);
  finish(localFile()); await downloading;
  report(0.1); // A late callback must not revert the completed state.
  entry = shelf.entries.find(entry => entry.book.id === book.id);
  assert.equal(entry.download.state, DownloadState.Downloaded);
  assert.equal(entry.book.hasLocalFile(), true);
  await shelf.downloadBook(entry.book); assert.equal(calls, 1);
  await shelf.downloadBook(book); assert.equal(calls, 1); // Ignore a stale UI callback after completion.
  const reader = new ReaderViewModel(app.bookshelf);
  assert.equal(await reader.open(entry.book), true);
  reader.progress = 0.42; await reader.saveProgress();
  const resumed = new ReaderViewModel(app.bookshelf);
  assert.equal(await resumed.open(entry.book), true); assert.equal(resumed.progress, 0.42);
});

test('download failure or invalid files preserve bookmarks and history, then allow a retry', async () => {
  for (const result of ['network-error', 'remote-url', 'empty-file']) {
    const app = createDemoApp(); let calls = 0;
    const downloader = { download: async () => {
      if (++calls === 2) return localFile();
      if (result === 'network-error') throw new Error('synthetic outage');
      return result === 'remote-url' ? new LocalBookFile('https://example.invalid/book', 123) :
        new LocalBookFile(localFile().uri, 0);
    } };
    const shelf = new BookshelfViewModel(app.bookshelf, app.importer, downloader);
    await shelf.load(); const book = shelf.books[0]; const before = shelf.history;
    await shelf.downloadBook(book);
    assert.equal(shelf.entries.find(entry => entry.book.id === book.id).download.state, DownloadState.Failed);
    assert.equal(shelf.books.length, 8);
    assert.equal(shelf.books.find(item => item.id === book.id).hasLocalFile(), false);
    assert.deepEqual(await app.bookshelf.listHistory(), before);
    await shelf.downloadBook(book);
    assert.equal(shelf.entries.find(entry => entry.book.id === book.id).download.state, DownloadState.Downloaded);
    assert.deepEqual(await app.bookshelf.listHistory(), before);
  }
});

test('an offline local import opens without an account or download, and an unready open cannot save progress', async () => {
  const app = createDemoApp(); let downloads = 0;
  const book = new Book('local-import', '本地文件', '测试', BookFormat.EPUB, '').withLocalFile(localFile());
  const shelf = new BookshelfViewModel(app.bookshelf, {importBook: async () => book},
    {download: async () => { downloads++; throw new Error('unexpected download'); }});
  await shelf.load(); await shelf.importBook();
  const entry = shelf.entries.find(entry => entry.book.id === book.id);
  assert.equal(entry.download.state, DownloadState.Downloaded);
  await shelf.downloadBook(entry.book); assert.equal(downloads, 0);
  const reader = new ReaderViewModel(app.bookshelf);
  assert.equal(await reader.open(entry.book), true);
  reader.progress = 0.25; await reader.saveProgress();
  assert.equal((await app.bookshelf.getReadingRecord(book.id)).progress, 0.25);
  const unready = new Book('unready', '仅收藏', '', BookFormat.PDF, '');
  assert.equal(await reader.open(unready), false);
  reader.progress = 0.8; await reader.saveProgress();
  assert.equal(await app.bookshelf.getReadingRecord(unready.id), undefined);
  assert.equal((await app.bookshelf.getReadingRecord(book.id)).progress, 0.25);
  assert.equal(await app.account.getSession(), undefined);
});
