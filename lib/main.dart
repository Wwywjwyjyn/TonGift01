import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'providers/core_providers.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: GiftMarketApp()));
}

class GiftMarketApp extends ConsumerWidget {
  const GiftMarketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // زبان مارکت انگلیسی است؛ فارسی از تنظیمات انتخاب می‌شود
    final fa = ref.watch(settingsProvider.select((s) => s.fa));
    return MaterialApp(
      title: 'Gift Market | بازار گیفت',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: Locale(fa ? 'fa' : 'en'),
      supportedLocales: const [Locale('en'), Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // راست‌به‌چپ فقط برای فارسی — انگلیسی چپ‌به‌راست
        return Directionality(
          textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
