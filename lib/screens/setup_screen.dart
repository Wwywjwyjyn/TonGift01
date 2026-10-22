import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/core_providers.dart';
import 'main_shell.dart';
import '../widgets/common.dart';

/// صفحه تنظیم بک‌اند — فقط بار اول یا بعداً از تنظیمات
class SetupScreen extends ConsumerStatefulWidget {
  final bool canGoBack;
  const SetupScreen({super.key, this.canGoBack = false});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _ctrl = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(settingsProvider).backendUrl;
    if (saved != null) _ctrl.text = saved;
  }

  Future<void> _testAndSave() async {
    final s = ref.read(settingsProvider).s;
    final url = _ctrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = s.fa ? 'آدرس بک‌اند را وارد کن' : 'Enter your backend URL');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await ref.read(settingsProvider.notifier).setBackendUrl(url);
      final ok = await ref.read(apiProvider).health();
      if (!ok) {
        setState(() {
          _testing = false;
          _error = s.fa
              ? 'بک‌اند پاسخ نداد /health — آدرس و اجرای سرور را چک کن'
              : 'Backend did not answer /health — check the URL and that the server is running';
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      setState(() {
        _testing = false;
        _error = '${s.errorOccurred}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    return Scaffold(
      appBar: widget.canGoBack ? AppBar(title: Text(s.setupTitle)) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.dns_rounded, size: 54, color: Color(AppColors.yellow)),
            const SizedBox(height: 14),
            Text(
              s.setupTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              s.setupDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, height: 2, color: Color(AppColors.textDim)),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://my-backend.onrender.com',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontFamily: 'Vazirmatn', color: Color(AppColors.red), fontSize: 12)),
            ],
            const SizedBox(height: 18),
            YellowButton(label: s.testConn, busy: _testing, onTap: _testAndSave),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(AppColors.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(AppColors.stroke)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.fa ? 'راهنمای سریع:' : 'Quick guide:',
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.fa
                        ? '۱. پوشه backend پروژه را روی یک هاست رایگان (مثل Render) اجرا کن.\n'
                            '۲. متغیر محیطی MARKETAPP_API_TOKEN را با توکن خودت ست کن.\n'
                            '۳. آدرس عمومی سرویس را همین‌جا وارد کن.'
                        : '1. Run the backend folder on a free host (e.g. Render).\n'
                            '2. Set the MARKETAPP_API_TOKEN environment variable with your token.\n'
                            '3. Enter the public URL of the service here.',
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, height: 2.1, color: Color(AppColors.textDim)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
