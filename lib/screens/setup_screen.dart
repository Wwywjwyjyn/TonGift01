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
    final url = _ctrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'آدرس بک‌اند را وارد کن');
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
          _error = 'بک‌اند پاسخ نداد /health — آدرس و اجرای سرور را چک کن';
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      setState(() {
        _testing = false;
        _error = 'خطا: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.canGoBack
          ? AppBar(title: const Text('تنظیم بک‌اند'))
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.dns_rounded, size: 54, color: Color(AppColors.yellow)),
            const SizedBox(height: 14),
            const Text(
              'اتصال به بک‌اند',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'این اپ به بک‌اند خودِ تو وصل می‌شود (سرور پراکسی امن با توکن API). توکن هرگز داخل اپ نیست. آدرس فقط روی همین گوشی ذخیره می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, height: 2, color: Color(AppColors.textDim)),
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
            YellowButton(label: 'تست و ادامه', busy: _testing, onTap: _testAndSave),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(AppColors.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(AppColors.stroke)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('راهنمای سریع:', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 13)),
                  SizedBox(height: 8),
                  Text(
                    '۱. پوشه backend پروژه را روی یک هاست رایگان (مثل Render) اجرا کن.\n'
                    '۲. متغیر محیطی MARKETAPP_API_TOKEN را با توکن خودت ست کن.\n'
                    '۳. آدرس عمومی سرویس را همین‌جا وارد کن.',
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, height: 2.1, color: Color(AppColors.textDim)),
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
