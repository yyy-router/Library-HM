const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

// Only pure logic is exercised. This identity decorator does not emulate ArkUI reactivity.
globalThis.Observed = target => target;
const load = file => require(path.join(process.cwd(), '.local/ci/logic/dist', file));
const { AppContainer } = load('app/AppContainer.js');
const { Book, BookFormat } = load('domain/model/Book.js');
const { ReadingRecord } = load('domain/model/ReadingRecord.js');
const { DemoBookCatalogRepository, DemoBookshelfRepository, DemoAccountRepository } = load('data/demo/DemoRepositories.js');
const { DemoFileImporter } = load('data/demo/DemoFileImporter.js');
const { HomeViewModel } = load('features/home/HomeViewModel.js');
const { BookshelfViewModel } = load('features/bookshelf/BookshelfViewModel.js');
const { ReaderViewModel } = load('features/reader/ReaderViewModel.js');

test('catalog searches title, author and format; empty query returns demo books', async () => {
  const catalog = new DemoBookCatalogRepository();
  assert.equal((await catalog.search('')).length, 3);
  assert.equal((await catalog.search('  pdf ')).length, 1);
  assert.equal((await catalog.search('指南')).length, 1);
  assert.equal((await catalog.search('演示书籍')).length, 3);
  assert.equal((await catalog.search('no-such-book')).length, 0);
});

test('bookshelf deduplicates IDs and returned list mutations do not alter storage', async () => {
  const shelf = new DemoBookshelfRepository();
  const book = new Book('test-book', '测试条目', '演示', BookFormat.EPUB, '');
  const original = (await shelf.listBooks()).length;
  await shelf.addBook(book); await shelf.addBook(book);
  const snapshot = await shelf.listBooks();
  assert.equal(snapshot.length, original + 1); assert.equal(snapshot[0].id, book.id);
  snapshot.pop();
  assert.equal((await shelf.listBooks()).length, original + 1);
});

test('history replaces a book record, sorts newest first and clamps progress', async () => {
  const shelf = new DemoBookshelfRepository();
  const [first, second] = await shelf.listBooks();
  await shelf.saveReadingRecord(new ReadingRecord(first, -1, 'demo:first', 10));
  await shelf.saveReadingRecord(new ReadingRecord(second, 0.5, 'demo:second', 20));
  await shelf.saveReadingRecord(new ReadingRecord(first, 2, 'demo:updated', 30));
  const history = await shelf.listHistory();
  assert.equal(history.length, 2); assert.equal(history[0].book.id, first.id);
  assert.equal(history[0].progress, 1); assert.equal(history[0].locator, 'demo:updated');
  assert.equal((await shelf.getReadingRecord(first.id)).progress, 1);
  assert.equal(await shelf.getReadingRecord('missing'), undefined);
  assert.equal((await new DemoBookshelfRepository().listHistory()).length, 0);
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
  const app = new AppContainer(); const home = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  await home.signIn(); assert.equal(home.busy, false); assert.match(home.message, /填写/);
  home.email = 'demo@example.invalid'; home.password = 'placeholder'; await home.signIn();
  assert.equal(home.password, ''); assert.equal(home.busy, false); assert.equal(home.session, undefined);
  assert.match(home.message, /尚未接入/);
});

test('search failures release busy state and display an error instead of success', async () => {
  const app = new AppContainer();
  const catalog = { search: async () => { throw new Error('synthetic failure'); } };
  const home = new HomeViewModel(catalog, app.bookshelf, app.account);
  await home.search(); assert.equal(home.busy, false); assert.match(home.message, /失败/);
});

test('cancelled and failed imports do not add records or leave the screen busy', async () => {
  const app = new AppContainer(); const count = (await app.bookshelf.listBooks()).length;
  const cancelled = new BookshelfViewModel(app.bookshelf, { importBook: async () => undefined });
  await cancelled.importBook(); assert.equal(cancelled.busy, false);
  const failed = new BookshelfViewModel(app.bookshelf, { importBook: async () => { throw new Error('synthetic failure'); } });
  await failed.importBook(); assert.equal(failed.busy, false); assert.match(failed.message, /失败/);
  assert.equal((await app.bookshelf.listBooks()).length, count);
});

test('shared container supports search, shelf addition, import, history and resume', async () => {
  const app = new AppContainer();
  const home = new HomeViewModel(app.catalog, app.bookshelf, app.account);
  const shelf = new BookshelfViewModel(app.bookshelf, app.importer);
  home.keyword = '指南'; await home.search(); await home.addToShelf(home.results[0]);
  await shelf.load(); assert.ok(shelf.books.some(book => book.id === home.results[0].id));
  await shelf.importBook(); const imported = shelf.books[0];
  const reader = new ReaderViewModel(app.bookshelf); await reader.open(imported);
  reader.progress = 0.42; await reader.saveProgress(); await shelf.load();
  assert.equal(shelf.history[0].book.id, imported.id);
  const resumed = new ReaderViewModel(app.bookshelf); await resumed.open(imported);
  assert.equal(resumed.progress, 0.42); assert.equal(resumed.busy, false);
});
