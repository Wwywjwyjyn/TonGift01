import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/core_providers.dart';
import '../../providers/tg_provider.dart';
import '../../services/tg_api.dart';
import '../../widgets/common.dart';

/// ورود به تلگرام داخل اپ — شماره ← کد ← (رمز دومرحله‌ای)
/// همه‌چیز از بک‌اند خودت رد می‌شود؛ نشست فقط روی سرور ذخیره می‌شود.
class TgConnectScreen extends ConsumerStatefulWidget {
  const TgConnectScreen({super.key});

  @override
  ConsumerState<TgConnectScreen> createState() => _TgConnectScreenState();
}

class _TgConnectScreenState extends ConsumerState<TgConnectScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  int _step = 0; // 0=phone 1=code 2=password
  bool _busy = false;
  String? _error;
  int? _flood;
  String _phone = '';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _err(Object e) {
    if (e is TgApiException) {
      setState(() {
        _error = e.detail;
        _flood = e.retryAfter;
      });
    } else {
      setState(() => _error = '$e');
    }
  }

  Future<void> _sendCode() async {
    final s = ref.read(settingsProvider).s;
    final phone = _phoneCtrl.text.trim();
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
      setState(() => _error = s.tgPhone);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _flood = null;
    });
    try {
      await ref.read(tgApiProvider).sendCode(phone);
      if (!mounted) return;
      setState(() {
        _phone = phone;
        _step = 1;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _err(e);
    }
  }

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
      _flood = null;
    });
    try {
      final r = await ref.read(tgApiProvider).signIn(_phone, '', code) as Map<String, dynamic>;
      if (!mounted) return;
      if (r['need_password'] == true) {
        setState(() {
          _step = 2;
          _busy = false;
        });
        return;
      }
      await _onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _err(e);
    }
  }

  Future<void> _submitPassword() async {
    if (_pwdCtrl.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _flood = null;
    });
    try {
      await ref.read(tgApiProvider).twoFa(_pwdCtrl.text);
      if (!mounted) return;
      await _onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pwdCtrl.clear();
      });
      _err(e);
    }
  }

  Future<void> _onSuccess() async {
    await ref.read(tgSessionProvider.notifier).check();
    if (!mounted) return;
    toast(context, 'Telegram connected ✓');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final titles = [s.tgConnect, s.tgCodeTitle, s.tg2faTitle];
    final hints = [s.tgPhoneHint, s.tgCodeHint, s.tg2faHint];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_step]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(AppColors.yellow).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.35)),
                ),
                child: Icon(
                  _step == 2 ? Icons.lock_rounded : Icons.telegram_rounded,
                  size: 38,
                  color: const Color(AppColors.yellow),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _step == 0 ? s.tgConnectDesc : hints[_step],
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: Color(AppColors.textDim), height: 1.9),
            ),
            const SizedBox(height: 18),

            if (_step == 0) ...[
              Text(s.tgPhone, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: s.tgPhoneHint),
              ),
              const SizedBox(height: 18),
              YellowButton(label: s.tgSendCode, busy: _busy, onTap: _sendCode),
            ],

            if (_step == 1) ...[
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(AppColors.blue).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.blue).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sms_rounded, size: 17, color: Color(AppColors.blue)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${s.tgCodeSentTo} $_phone',
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.blue)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                onChanged: (v) {
                  setState(() {});
                  if (v.replaceAll(RegExp(r'[^0-9]'), '').length >= 5) _submitCode();
                },
                decoration: const InputDecoration(counterText: '', hintText: '• • • • •'),
              ),
              const SizedBox(height: 14),
              YellowButton(label: s.tgContinue, busy: _busy, onTap: _submitCode),
              const SizedBox(height: 10),
              GhostButton(label: s.retry, onTap: _busy ? null : () => setState(() => _step = 0), color: const Color(AppColors.textDim)),
            ],

            if (_step == 2) ...[
              TextField(
                controller: _pwdCtrl,
                obscureText: true,
                autofocus: true,
                onSubmitted: (_) => _submitPassword(),
                decoration: InputDecoration(hintText: s.tg2faHint),
              ),
              const SizedBox(height: 18),
              YellowButton(label: s.tgContinue, busy: _busy, onTap: _submitPassword),
            ],

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(AppColors.red).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.red).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(AppColors.red)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _flood != null ? s.tgFloodWait(_flood!) : _error!,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red), height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
