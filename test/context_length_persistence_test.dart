import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/data/database/database.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression guard for the removed 1M → 300K context-window migration.
///
/// 0.1.12+32 shipped a 300K default and migrated any config still sitting on
/// exactly 1M down to it. 0.1.12+33 flipped the built-in DS-zh preset back to
/// 1M, which meant that every preset apply was silently undone on the next
/// launch — the stored 1M value was indistinguishable from the old default.
/// The migration is gone as of 0.1.12+34; these tests pin the behaviour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({SharedPreferences prefs, AppDatabase db})> setUpStore(
    LLMConfig initial,
  ) async {
    SharedPreferences.setMockInitialValues({
      'llm_config': jsonEncode(initial.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    return (prefs: prefs, db: database);
  }

  test('the preset 1M window is not migrated down to 300K on load', () async {
    const initial = LLMConfig(
      provider: LLMProvider.openAICompatible,
      model: 'test-model',
      apiKey: 'test-key',
      apiUrl: 'https://example.com/v1',
      contextLength: 1000000,
    );
    final store = await setUpStore(initial);

    final notifier = LLMConfigNotifier(store.prefs, store.db);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await notifier.flushPersistence();

    expect(notifier.state.contextLength, 1000000);

    // A second load (i.e. an app restart) must keep it, and the value written
    // back to the database must still be 1M.
    final reloaded = LLMConfigNotifier(store.prefs, store.db);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await reloaded.flushPersistence();
    expect(reloaded.state.contextLength, 1000000);

    final row = await (store.db.select(store.db.globalStates)
          ..where((r) => r.key.equals('llm_config')))
        .getSingle();
    expect(
      (jsonDecode(row.value) as Map<String, dynamic>)['contextLength'],
      1000000,
    );
  });

  test('a hand-picked context window is left untouched', () async {
    const initial = LLMConfig(
      provider: LLMProvider.openAICompatible,
      model: 'test-model',
      apiKey: 'test-key',
      apiUrl: 'https://example.com/v1',
      contextLength: 32000,
    );
    final store = await setUpStore(initial);

    final notifier = LLMConfigNotifier(store.prefs, store.db);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.state.contextLength, 32000);
  });
}
