import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/core_providers.dart';
import '../../providers/tg_provider.dart';
import '../../widgets/common.dart';

/// گیت API تلگرام — فقط و فقط برای اولین نفری که اپ را باز می‌کند
/// - اختیاری: رد شود، دفعه بعد ورود دوباره نشان داده می‌شود تا کامل کند
/// - بعد از ذخیره: دیگر هرگز نشان داده نمی‌شود (نه به او، نه به کس دیگری)
/// - مقادیر فقط روی بک‌اند ذخیره می‌شوند و هرگز به هیچ کلاینتی برنمی‌گردند
class ApiGateScreen extends ConsumerStatefulWidget {
  const ApiGateScreen({super.key});

  @override
  ConsumerState<ApiGateScreen> createState() => _ApiGateScreenState();
}

class _ApiGateScreenState extends ConsumerState<ApiGateScreen> {
  final _idCtrl = TextEditingController();
  final _hashCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _hashCtrl.dispose();
    super.dispose();
  }

  bool get _idValid => int.tryParse(_idCtrl.text.trim()) != null && int.parse(_idCtrl.text.trim()) > 0;
  bool get _hashValid => RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(_hashCtrl.text.trim());

  Future<void> _save() async {
    final s = ref.read(settingsProvider).s;
    if (!_idValid) {
      setState(() => _error = s.invalidApiId);
      return;
    }
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(_hashCtrl.text.trim())) {
      setState(() => _error = s.invalidApiHash);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(ownerGateProvider.notifier).claim(
          _idCtrl.text.trim(),
          _hashCtrl.text.trim().toLowerCase(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      toast(context, s.apiGateDone);
      // API ذخیره شد — وضعیت تلگرام را دوباره بگیر تا دکمه ورود فعال شود
      ref.read(tgSessionProvider.notifier).check();
      Navigator.pop(context);
    } else {
      setState(() => _error = ref.read(settingsProvider).s.errorOccurred);
    }
  }

  void _skip() {
    // رد کردن فقط برای همین اجرا — دفعه بعد ورود باز نشان داده می‌شود (تا وقتی نرسانده)
    ref.read(ownerGateProvider.notifier).dismissedThisSession();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.apiGateTitle),
        actions: [
          TextButton(
            onPressed: _busy ? null : _skip,
            child: Text(s.later, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: Color(AppColors.textDim))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // آیکون
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(AppColors.yellow).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.35)),
                ),
                child: const Icon(Icons.vpn_key_rounded, size: 36, color: Color(AppColors.yellow)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.apiGateTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              s.apiGateDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Color(AppColors.textDim), height: 1.9),
            ),
            const SizedBox(height: 12),
            // یادداشت مالک — فقط نفر اول
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(AppColors.green).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.green).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 17, color: Color(AppColors.green)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      s.apiGateOwnerNote,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, height: 1.8, color: Color(AppColors.green)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // API ID
            Text(s.apiId, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
              controller: _idCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: s.apiIdHint),
            ),
            const SizedBox(height: 13),
            // API Hash
            Text(s.apiHash, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            TextField(
              controller: _hashCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: s.apiHashHint),
            ),
            const SizedBox(height: 8),
            Text(
              s.apiGateWhere,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red))),
            ],
            const SizedBox(height: 18),
            YellowButton(
              label: s.apiGateSave,
              busy: _busy,
              onTap: (_idValid && RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(_hashCtrl.text.trim())) ? _save : null,
            ),
            const SizedBox(height: 10),
            GhostButton(label: s.later, onTap: _busy ? null : _skip),
            const SizedBox(height: 10),
            Center(
              child: Text(
                s.apiGateSkipNote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim), height: 1.8),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
