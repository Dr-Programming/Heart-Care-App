import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/localization/language.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales:
          AppLanguage.values.map((AppLanguage l) => l.locale).toList(),
      path: 'assets/translations',
      fallbackLocale: AppLanguage.en.locale,
      child: const ProviderScope(child: LibuCareApp()),
    ),
  );
}

class LibuCareApp extends ConsumerWidget {
  const LibuCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Libu Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(context.locale.languageCode),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
