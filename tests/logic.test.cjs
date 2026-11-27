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
const { BookDetailsViewModel } = load('features/details/BookDetailsViewModel.js');
const { BookDetails } = load('domain/model/BookDetails.js');
const { MemoryBookshelfRepository } = load('data/local/MemoryBookshelfRepository.js');
const { RemoteBookSource } = load('domain/model/RemoteBookSource.js');
const { BookCoverViewModel } = load('shared/components/BookCoverViewModel.js');
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

function detailDeferred() {
  let resolve, reject;
  const promise = new Promise((success, failure) => { resolve = success; reject = failure; });
  return { promise, resolve, reject };
}

const remoteDetailBook = (id = 'a', url = 'https://covers.example.invalid/a.jpg', origin = 'https://example.invalid') =>
  new Book(`remote:${id}:hash`, `Book ${id}`, 'Author', BookFormat.Unknown, '', '', false, '', 0.75, '', undefined,
    new RemoteBookSource(origin, id, 'hash', url));
const flushCover = () => new Promise(resolve => setImmediate(resolve));

test('cover metadata updates preserve the current image and a replacement failure keeps the same book cover', async () => {
  const first = detailDeferred(), replacement = detailDeferred();
  let calls = 0;
  const repository = { getCached: () => undefined, load: () => ++calls === 1 ? first.promise : replacement.promise };
  const vm = new BookCoverViewModel();
  vm.update(remoteDetailBook(), repository);
  assert.equal(calls, 1);
  vm.update(remoteDetailBook(), repository);
  assert.equal(calls, 1, 'a metadata update must not replace a pending request');
  first.resolve('cover-a'); await flushCover();
  assert.equal(vm.image, 'cover-a');
  vm.update(remoteDetailBook().asBookmark(), repository);
  assert.equal(vm.image, 'cover-a'); assert.equal(calls, 1);
  vm.update(remoteDetailBook('a', 'https://covers.example.invalid/new-a.jpg'), repository);
  assert.equal(vm.image, 'cover-a'); assert.equal(calls, 2);
  replacement.reject(new Error('Unavailable replacement')); await flushCover();
  assert.equal(vm.image, 'cover-a');
});

test('cached covers display synchronously and late results never replace another book or a closed cover', async () => {
  const late = detailDeferred(); let calls = 0;
  const repository = { getCached: url => url.endsWith('/a.jpg') ? 'cached-a' : undefined,
    load: () => { calls++; return late.promise; } };
  const vm = new BookCoverViewModel();
  vm.update(remoteDetailBook(), repository);
  assert.equal(vm.image, 'cached-a'); assert.equal(calls, 0);
  vm.update(remoteDetailBook('b', 'https://covers.example.invalid/b.jpg'), repository);
  assert.equal(vm.image, ''); assert.equal(calls, 1);
  vm.update(remoteDetailBook(), repository);
  assert.equal(vm.image, 'cached-a');
  late.resolve('late-b'); await flushCover(); assert.equal(vm.image, 'cached-a');
  const pending = detailDeferred();
  const closed = new BookCoverViewModel();
  closed.update(remoteDetailBook('c'), { getCached: () => undefined, load: () => pending.promise });
  closed.close(); pending.resolve('late-c'); await flushCover();
  assert.equal(closed.image, '');
});

test('reopening recent details displays cached content immediately while refreshing shelf and preserving current local state', async () => {
  let calls = 0, shelfCalls = 0;
  const book = remoteDetailBook();
  const vm = new BookDetailsViewModel({ getDetails: async selected => { calls++; return new BookDetails(selected, 'Publisher'); } },
    { listBooks: async () => { shelfCalls++; return []; } });
  await vm.open(book); vm.close();
  const again = vm.open(book.withLocalFile(localFile()));
  assert.equal(vm.loading, false); assert.equal(vm.details.publisher, 'Publisher');
  assert.equal(vm.book.hasLocalFile(), true); assert.equal(calls, 1);
  await again; assert.equal(shelfCalls, 2);
  await vm.open(remoteDetailBook('a', 'https://covers.example.invalid/a.jpg', 'https://other.example.invalid'));
  assert.equal(calls, 2, 'origins must have separate detail caches');
});

test('opening details finishes only after both content and shelf state are ready', async () => {
  const content = detailDeferred(), shelf = detailDeferred();
  const book = remoteDetailBook(); let complete = false;
  const vm = new BookDetailsViewModel({ getDetails: () => content.promise }, { listBooks: () => shelf.promise });
  const opening = vm.open(book).then(() => { complete = true; });
  assert.equal(vm.loading, true); assert.equal(vm.shelfLoading, true);
  content.resolve(new BookDetails(book, 'Publisher')); await flushCover();
  assert.equal(vm.loading, false); assert.ok(vm.details); assert.equal(complete, false);
  shelf.resolve([book]); await opening;
  assert.equal(complete, true); assert.equal(vm.saved, true); assert.equal(vm.shelfLoading, false);
});

test('successful detail completion and cache hits never become errors while a loading overlay exits', async () => {
  const content = detailDeferred(), shelf = detailDeferred();
  const book = remoteDetailBook();
  const vm = new BookDetailsViewModel({ getDetails: () => content.promise }, { listBooks: () => shelf.promise });
  assert.equal(vm.hasLoadError, false);
  const opening = vm.open(book);
  assert.equal(vm.hasLoadError, false);
  content.resolve(new BookDetails(book, 'Publisher')); await flushCover();
  assert.equal(vm.loading, false); assert.equal(vm.shelfLoading, true);
  assert.equal(vm.hasLoadError, false, 'content completion before shelf state must not show an error');
  shelf.resolve([]); await opening;
  assert.equal(vm.hasLoadError, false, 'a retained loading overlay must still render its spinner after success');
  vm.close(); assert.equal(vm.hasLoadError, false);
  const cached = vm.open(book);
  assert.equal(vm.loading, false); assert.equal(vm.hasLoadError, false);
  await cached;
});

test('only actual detail failures enable the error panel; retry and cancellation clear it', async () => {
  const book = remoteDetailBook(); let response = Promise.reject(new AppError('HTTP_TIMEOUT', '请求超时'));
  const vm = new BookDetailsViewModel({ getDetails: () => response }, new MemoryBookshelfRepository());
  await vm.open(book);
  assert.equal(vm.hasLoadError, true); assert.equal(vm.message, '请求超时');
  const pending = detailDeferred(); response = pending.promise;
  const retry = vm.open(book);
  assert.equal(vm.hasLoadError, false); assert.equal(vm.message, '');
  vm.close(); assert.equal(vm.hasLoadError, false);
  pending.reject(new AppError('HTTP_TIMEOUT', '迟到超时')); await retry;
  assert.equal(vm.loading, false); assert.equal(vm.hasLoadError, false); assert.equal(vm.message, '');
  response = Promise.resolve(new BookDetails(book));
  await vm.open(book); assert.equal(vm.hasLoadError, false);
});

test('detail cache expires after five minutes, evicts old entries and never remembers a failed response', async () => {
  let now = 0, calls = 0, fail = false;
  const vm = new BookDetailsViewModel({ getDetails: async book => {
    calls++; if (fail) throw new AppError('NETWORK_ERROR', 'Retry later'); return new BookDetails(book);
  } }, new MemoryBookshelfRepository(), () => now);
  await vm.open(remoteDetailBook()); await vm.open(remoteDetailBook());
  assert.equal(calls, 1);
  now = 5 * 60 * 1000;
  await vm.open(remoteDetailBook()); assert.equal(calls, 2);
  for (let index = 0; index < 12; index++) await vm.open(remoteDetailBook(`entry-${index}`));
  await vm.open(remoteDetailBook()); assert.equal(calls, 15);
  fail = true;
  await vm.open(remoteDetailBook('failed')); assert.ok(vm.message);
  fail = false;
  await vm.open(remoteDetailBook('failed')); assert.equal(vm.message, ''); assert.equal(calls, 17);
});

test('details can be saved independently of login or loading failure and duplicate saves preserve existing local files', async () => {
  const book = new Book('details-1', 'Selected book', 'Author', BookFormat.PDF, '', '', false);
  const shelf = new MemoryBookshelfRepository();
  const details = new BookDetailsViewModel({ getDetails: async () => { throw new AppError('AUTH_REQUIRED', '请登录'); } }, shelf);
  await details.open(book);
  assert.equal(details.requiresLogin, true); assert.equal(details.loading, false);
  assert.equal(details.shelfReady, true); assert.equal(details.saved, false);
  await Promise.all([details.save(), details.save()]);
  assert.equal(details.saved, true); assert.equal((await shelf.listBooks()).length, 1);
  assert.equal((await shelf.listBooks())[0].hasLocalFile(), false);
  await shelf.saveLocalFile(book.id, localFile());
  await details.open(book);
  assert.equal(details.saved, true);
  await details.save();
  assert.equal((await shelf.listBooks())[0].hasLocalFile(), true);
});

test('details ignore late successes, failures and shelf lookups after selecting another book or leaving', async () => {
  for (const lateFailure of [false, true]) {
    const oldDetails = detailDeferred(), oldShelf = detailDeferred();
    const a = new Book('a', 'Book A', '', BookFormat.PDF, '');
    const b = new Book('b', 'Book B', '', BookFormat.EPUB, '');
    let shelfCalls = 0;
    const vm = new BookDetailsViewModel({ getDetails: book => book.id === 'a' ? oldDetails.promise : Promise.resolve(new BookDetails(b)) },
      { listBooks: () => ++shelfCalls === 1 ? oldShelf.promise : Promise.resolve([]) });
    const old = vm.open(a);
    await vm.open(b);
    if (lateFailure) { oldDetails.reject(new AppError('AUTH_REQUIRED', 'Old session')); oldShelf.reject(new Error('Old shelf')); }
    else { oldDetails.resolve(new BookDetails(a)); oldShelf.resolve([a]); }
    await old;
    assert.equal(vm.book.id, 'b'); assert.equal(vm.details.book.id, 'b');
    assert.equal(vm.saved, false); assert.equal(vm.requiresLogin, false);
    assert.equal(vm.message, ''); assert.equal(vm.shelfMessage, '');
    assert.equal(vm.shelfReady, true); assert.equal(vm.loading, false);
    const final = detailDeferred();
    const closed = new BookDetailsViewModel({ getDetails: () => final.promise }, new MemoryBookshelfRepository());
    const loading = closed.open(a); closed.close();
    final.resolve(new BookDetails(b)); await loading;
    assert.equal(closed.details, undefined); assert.equal(closed.book.id, 'a');
    assert.equal(closed.loading, false);
  }
});

test('details retry fetch and shelf errors without a blind save or exposing internal errors', async () => {
  const book = new Book('a', 'Book A', '', BookFormat.PDF, '');
  let rejectDetail = true, rejectShelf = true, additions = 0;
  const vm = new BookDetailsViewModel({ getDetails: async () => {
    if (rejectDetail) throw new Error('synthetic-internal-error'); return new BookDetails(book, 'Publisher');
  } }, { listBooks: async () => { if (rejectShelf) throw new Error('synthetic-internal-error'); return []; },
    addBook: async () => { additions++; } });
  await vm.open(book);
  assert.equal(vm.shelfReady, false); assert.ok(vm.message); assert.ok(vm.shelfMessage);
  assert.ok(!vm.message.includes('synthetic-internal-error'));
  await vm.save(); assert.equal(additions, 0);
  rejectDetail = false; rejectShelf = false;
  await Promise.all([vm.loadDetails(), vm.refreshShelf()]);
  assert.equal(vm.message, ''); assert.equal(vm.shelfMessage, ''); assert.equal(vm.details.publisher, 'Publisher');
  await vm.save(); assert.equal(additions, 1); assert.equal(vm.saved, true);
});

test('a late save cannot mark a different details page as saved and saves contain bookmarks only', async () => {
  const pending = detailDeferred(); const added = [];
  const a = new Book('a', 'Book A', '', BookFormat.PDF, '', '', false).withLocalFile(localFile());
  const b = new Book('b', 'Book B', '', BookFormat.EPUB, '');
  const vm = new BookDetailsViewModel({ getDetails: async book => new BookDetails(book) },
    { listBooks: async () => [], addBook: async book => { added.push(book); await pending.promise; } });
  await vm.open(a);
  const save = vm.save();
  await vm.open(b);
  pending.resolve(); await save;
  assert.equal(added.length, 1); assert.equal(added[0].id, 'a'); assert.equal(added[0].hasLocalFile(), false);
  assert.equal(vm.book.id, 'b'); assert.equal(vm.saved, false); assert.equal(vm.saving, false);
  assert.equal(vm.shelfMessage, '');
});

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

test('slow authentication recovery cannot overwrite a newer login or search message', async () => {
  const app = createDemoApp(); const results = (await app.catalog.search('')).slice(0, 1);
  for (const action of ['login', 'search']) {
    let releasePopular, notifyRecovery, searches = 0;
    const recovering = new Promise(resolve => { notifyRecovery = resolve; });
    const home = new HomeViewModel({ search: async () => {
      if (++searches === 1) throw new AppError('AUTH_REQUIRED', '测试：旧登录失效');
      return results;
    }, getRecommended: async () => [], getPopular: () => {
      notifyRecovery(); return new Promise(resolve => { releasePopular = resolve; });
    } }, app.bookshelf, { signIn: async () => new AccountSession('new-account', '新读者') });
    home.session = new AccountSession('old-account', '旧读者'); home.keyword = 'old';
    const oldSearch = home.search(); await recovering;
    assert.equal(home.busy, false); assert.equal(home.message, '测试：旧登录失效');
    if (action === 'login') {
      home.email = 'reader@example.invalid'; home.password = 'synthetic-password'; await home.signIn();
      assert.equal(home.message, '登录成功。');
    } else {
      home.keyword = 'new'; await home.search(); assert.equal(home.message, '');
    }
    const currentMessage = home.message;
    releasePopular([]); await oldSearch;
    assert.equal(home.message, currentMessage);
    if (action === 'login') assert.equal(home.session.accountId, 'new-account');
    else assert.deepEqual(home.results, results);
  }
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
