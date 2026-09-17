import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_wiring.dart';
import 'core/localization/language.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Portrait only. The design is drawn for one orientation, and a rotated
  // form on a low-end phone is a reliable way to lose half-entered input.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: AppLanguage.values
          .map((AppLanguage l) => l.locale)
          .toList(growable: false),
      path: 'assets/translations',
      fallbackLocale: AppLanguage.en.locale,
      // Amharic is a full alternative, not a partial translation
      // (FR-LOC-002). Falling back key-by-key would produce screens that mix
      // scripts, so a missing key is a bug to fix rather than to paper over.
      useFallbackTranslations: true,
      child: ProviderScope(
        overrides: featureOverrides(),
        child: const LibuCareApp(),
      ),
    ),
  );
}

class LibuCareApp extends ConsumerWidget {
  const LibuCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => 'app.name'.tr(),
      debugShowCheckedModeBanner: false,
      // The theme depends on the locale: Poppins has no Ethiopic glyphs, so
      // Amharic needs a different family. See AppTypography.
      theme: AppTheme.light(context.locale.languageCode),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
    );
  }
}
