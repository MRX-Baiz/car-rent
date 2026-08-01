import 'dart:io';

import 'package:car_rent_manager/core/storage/media_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory storage;
  late Directory pickerCache;
  late MediaStore store;

  setUp(() {
    storage = Directory.systemTemp.createTempSync('media_store_');
    // Stands in for the cache image_picker/file_picker copy into.
    pickerCache = Directory.systemTemp.createTempSync('picker_cache_');
    store = MediaStore.instance..debugSetDirectory(storage);
  });

  tearDown(() {
    for (final dir in [storage, pickerCache]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  File pickedFile(String name, {String content = 'image-bytes'}) {
    return File(p.join(pickerCache.path, name))..writeAsStringSync(content);
  }

  // This is the reported bug: attach a permis, save, come back later and the
  // picture is gone. The row kept a path into a cache Android had emptied.
  test('an attachment survives the picker cache being wiped', () async {
    final picked = pickedFile('permis.jpg', content: 'permis-scan');
    final stored = await store.save(picked, prefix: 'permis');

    // Android reclaiming the app cache, and the app restarting.
    pickerCache.deleteSync(recursive: true);
    MediaStore.instance.debugSetDirectory(storage);

    final resolved = store.resolveSync(stored);
    expect(resolved, isNotNull,
        reason: 'the attachment must outlive the picker cache');
    expect(File(resolved!).readAsStringSync(), 'permis-scan');
  });

  test('stores a name, not a path, so the container can move', () async {
    final stored = await store.save(pickedFile('cin.png'), prefix: 'cin');

    expect(p.isAbsolute(stored), isFalse,
        reason: 'an absolute path breaks when iOS moves the app container');
    expect(stored, contains('cin'));
    expect(p.extension(stored), '.png');
  });

  test('resolves against wherever the container is now', () async {
    final stored = await store.save(pickedFile('logo.png'), prefix: 'logo');

    // The same files, reached through a different path — an app update on iOS.
    final moved = Directory.systemTemp.createTempSync('moved_container_');
    File(p.join(storage.path, stored)).copySync(p.join(moved.path, stored));
    store.debugSetDirectory(moved);

    expect(store.resolveSync(stored), p.join(moved.path, stored));
    moved.deleteSync(recursive: true);
  });

  test('keeps two attachments saved in the same millisecond apart', () async {
    final first = await store.save(pickedFile('a.jpg'), prefix: 'cin');
    final second = await store.save(pickedFile('b.jpg'), prefix: 'cin');

    expect(first, isNot(second));
    expect(storage.listSync().length, 2);
  });

  test('replacing an attachment leaves the old one readable', () async {
    final first =
        await store.save(pickedFile('old.jpg', content: 'old'), prefix: 'cin');
    await store.save(pickedFile('new.jpg', content: 'new'), prefix: 'cin');

    expect(File(store.resolveSync(first)!).readAsStringSync(), 'old',
        reason: 'a save must not overwrite an unrelated attachment');
  });

  group('resolveSync', () {
    test('returns null for nothing stored', () {
      expect(store.resolveSync(null), isNull);
      expect(store.resolveSync(''), isNull);
    });

    test('returns null when the file is missing', () async {
      final stored = await store.save(pickedFile('gone.jpg'), prefix: 'cin');
      File(p.join(storage.path, stored)).deleteSync();

      expect(store.resolveSync(stored), isNull,
          reason: 'callers show a placeholder rather than a broken image');
    });

    test('still honours a legacy absolute path that survived', () {
      final legacy = pickedFile('legacy.jpg');
      expect(store.resolveSync(legacy.path), legacy.path);
    });

    test('returns null for a legacy absolute path that did not', () {
      final legacy = pickedFile('legacy.jpg');
      final path = legacy.path;
      legacy.deleteSync();

      expect(store.resolveSync(path), isNull);
    });
  });

  group('delete', () {
    test('removes a stored attachment', () async {
      final stored = await store.save(pickedFile('x.jpg'), prefix: 'cin');
      await store.delete(stored);

      expect(store.resolveSync(stored), isNull);
    });

    test('refuses to touch a legacy absolute path', () async {
      final outside = pickedFile('not-ours.jpg');
      await store.delete(outside.path);

      expect(outside.existsSync(), isTrue,
          reason: 'that path may be a file the app does not own');
    });
  });
}
