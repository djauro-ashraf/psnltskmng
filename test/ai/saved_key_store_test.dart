import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/saved_key_store.dart';

void main() {
  late InMemoryApiKeyStore vault;
  late SavedKeyStore store;

  setUp(() {
    vault = InMemoryApiKeyStore();
    store = SavedKeyStore(vault);
  });

  test('starts empty, and the very first save works', () async {
    expect(await store.all(), isEmpty);
    final replaced = await store.save(
      providerId: 'gemini',
      name: 'Personal',
      key: 'k1',
    );
    expect(replaced, isFalse);
    expect((await store.all()).single.name, 'Personal');
  });

  test('lists one provider at a time, sorted by name ignoring case', () async {
    await store.save(providerId: 'gemini', name: 'work', key: 'k1');
    await store.save(providerId: 'gemini', name: 'Alpha', key: 'k2');
    await store.save(providerId: 'groq', name: 'Other', key: 'k3');

    final gemini = await store.forProvider('gemini');
    expect([for (final k in gemini) k.name], ['Alpha', 'work']);
    final groq = await store.forProvider('groq');
    expect([for (final k in groq) k.name], ['Other']);
  });

  test('the same name replaces the old key, ignoring case and spaces', () async {
    await store.save(providerId: 'gemini', name: 'Personal', key: 'old');
    final replaced = await store.save(
      providerId: 'gemini',
      name: '  personal ',
      key: 'new',
    );

    expect(replaced, isTrue);
    final all = await store.all();
    expect(all, hasLength(1));
    expect(all.single.key, 'new');
  });

  test('the same name can exist for two providers', () async {
    await store.save(providerId: 'gemini', name: 'Main', key: 'g');
    final replaced = await store.save(
      providerId: 'groq',
      name: 'Main',
      key: 'q',
    );

    expect(replaced, isFalse);
    expect(await store.all(), hasLength(2));
  });

  test('name and key are trimmed; empty ones are refused', () async {
    await store.save(providerId: 'gemini', name: ' Main ', key: ' k ');
    final saved = (await store.all()).single;
    expect(saved.name, 'Main');
    expect(saved.key, 'k');

    await expectLater(
      store.save(providerId: 'gemini', name: '  ', key: 'k'),
      throwsArgumentError,
    );
    await expectLater(
      store.save(providerId: 'gemini', name: 'x', key: ' '),
      throwsArgumentError,
    );
  });

  test('find and remove work by id; removing the last clears the entry', () async {
    await store.save(providerId: 'gemini', name: 'A', key: 'ka');
    await store.save(providerId: 'gemini', name: 'B', key: 'kb');
    final idA = SavedApiKey.idOf('gemini', 'a');

    expect((await store.find(idA))?.key, 'ka');
    expect(await store.remove(idA), isTrue);
    expect(await store.find(idA), isNull);
    expect(await store.remove(idA), isFalse);

    expect(await store.remove(SavedApiKey.idOf('gemini', 'B')), isTrue);
    expect(await vault.read(SavedKeyStore.vaultName), isNull);
  });

  test('keys survive a new store over the same vault', () async {
    await store.save(providerId: 'gemini', name: 'Main', key: 'k');
    final again = SavedKeyStore(vault);
    expect((await again.find(SavedApiKey.idOf('gemini', 'Main')))?.key, 'k');
  });

  test('unreadable text counts as nothing saved; the next save repairs it', () async {
    await vault.write(SavedKeyStore.vaultName, '{not json');
    expect(await store.all(), isEmpty);

    await store.save(providerId: 'gemini', name: 'Main', key: 'k');
    expect(await store.all(), hasLength(1));
  });

  test('entries that are not complete are skipped', () async {
    await vault.write(
      SavedKeyStore.vaultName,
      '[{"provider":"gemini","name":"Good","key":"k"},'
      '{"provider":"gemini","name":"","key":"k"},'
      '{"provider":"gemini","name":"NoKey"},'
      '"junk"]',
    );
    expect([for (final k in await store.all()) k.name], ['Good']);
  });

  test('toString never shows the key', () {
    const saved = SavedApiKey(providerId: 'gemini', name: 'Main', key: 'SECRET');
    expect(saved.toString(), isNot(contains('SECRET')));
  });
}
