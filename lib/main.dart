import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_tavern/app.dart';
import 'package:native_tavern/core/services/initialization_service.dart';
import 'package:native_tavern/data/models/ai_preset.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/chat_repository.dart';
import 'package:native_tavern/data/repositories/world_info_repository.dart';
import 'package:native_tavern/domain/services/llm_service.dart';
import 'package:native_tavern/domain/services/import_service.dart';
import 'package:native_tavern/domain/services/ai_data_sharing_consent_service.dart';
import 'package:native_tavern/domain/services/external_call_audit_service.dart';
import 'package:native_tavern/presentation/providers/ai_data_sharing_consent_providers.dart';
import 'package:native_tavern/presentation/providers/ai_preset_providers.dart';
import 'package:native_tavern/presentation/providers/external_call_audit_providers.dart';
import 'package:native_tavern/presentation/providers/settings_providers.dart';
import 'package:native_tavern/presentation/screens/import/import_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chat list / day divider dates are formatted with `intl`, which needs its
  // locale symbol tables before the first `DateFormat` call.
  await initializeDateFormatting();

  // Initialize core services
  final initData = await InitializationService.initialize();

  // Get shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Create repositories
  final database = initData.database;
  final characterRepo = CharacterRepository(database, initData.dataPath);
  final chatRepo = ChatRepository(database);
  final worldInfoRepo = WorldInfoRepository(database);

  // Create services
  final externalCallAudit = FileExternalCallAuditRepository(
    dataPath: initData.dataPath,
  );
  final aiDataSharingConsent =
      SharedPreferencesAiDataSharingConsentRepository(prefs);
  final llmService = LLMService(
    auditRepository: externalCallAudit,
    consentRepository: aiDataSharingConsent,
  );
  final importService = ImportService(initData.dataPath);

  final container = ProviderContainer(
    overrides: [
      // Database
      databaseProvider.overrideWithValue(database),
      dataPathProvider.overrideWithValue(initData.dataPath),

      // Repositories
      characterRepositoryProvider.overrideWithValue(characterRepo),
      chatRepositoryProvider.overrideWithValue(chatRepo),
      worldInfoRepositoryProvider.overrideWithValue(worldInfoRepo),

      // Services
      llmServiceProvider.overrideWithValue(llmService),
      importServiceProvider.overrideWithValue(importService),
      externalCallAuditRepositoryProvider.overrideWithValue(
        externalCallAudit,
      ),
      aiDataSharingConsentRepositoryProvider.overrideWithValue(
        aiDataSharingConsent,
      ),

      // Shared preferences
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // First launch (no AI preset ever chosen): default-enable the built-in
  // DS-zh preset — applies DS V4 Flash samplers + Chinese system prompt and
  // Chinese post-history instructions, identical to tapping it in the UI.
  if (!prefs.containsKey(activeAIPresetIdKey)) {
    try {
      await container
          .read(aiPresetManagerProvider)
          .applyPreset(BuiltInAIPresets.dsZh);
      debugPrint('✅ Default DS-zh preset applied on first launch');
    } catch (e) {
      debugPrint('⚠️ Failed to apply default DS-zh preset: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NativeTavernApp(),
    ),
  );
}
