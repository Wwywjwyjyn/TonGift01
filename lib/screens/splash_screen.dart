import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import 'setup_screen.dart';
import 'main_shell.dart';

/// اسپلش — هیچ‌وقت در لودینگ گیر نمی‌کند (همه‌چیز با timeout)
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    // حداکثر ۱.۶ ثانیه — بعد از آن قطعاً ناوبری انجام می‌شود
    await Future.any([
      _waitAndNavigate(),
      Future.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted || _navigated) return;
    _navigate(false);
  }

  Future<void> _waitAndNavigate() async {
    // منتظر لود شدن تنظیمات بمان (حداکثر ۱.۴ ثانیه)
    final deadline = DateTime.now().add(const Duration(milliseconds: 1400));
    while (DateTime.now().isBefore(deadline)) {
      if (ref.read(settingsProvider).loaded) break;
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;
    _navigate(ref.read(settingsProvider).backendUrl?.isNotEmpty ?? false);
  }

  void _navigate(bool hasBackend) {
    _navigated = true;
    final target = hasBackend ? const MainShell() : const SetupScreen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD600),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.card_giftcard_rounded, size: 48, color: Color(0xFF111111)),
            ),
            const SizedBox(height: 18),
            const Text(
              'بازار گیفت',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'مارکت واقعی گیفت‌های تلگرام — TON و استارز',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Color(0xFF9A9AA3)),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFFFD600)),
            ),
          ],
        ),
      ),
    );
  }
}
