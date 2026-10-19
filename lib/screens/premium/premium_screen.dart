import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tx_flow.dart';

/// Telegram Premium — سه گزینه با قیمت واقعی TON از API
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  int _months = 3;
  final _userCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  PremiumPrices? _prices;

  bool _recLoading = false;
  String? _recName;
  String? _recPhoto;
  String? _recError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiProvider).premiumPrice();
      setState(() => _prices = PremiumPrices.fromJson(r as Map<String, dynamic>));
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkRecipient() async {
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      setState(() => _recError = 'یوزرنیم گیرنده را وارد کن');
      return;
    }
    setState(() {
      _recLoading = true;
      _recError = null;
      _recName = null;
      _recPhoto = null;
    });
    try {
      final r = await ref.read(apiProvider).premiumRecipient(u);
      setState(() {
        _recName = (r['name'] ?? '').toString();
        _recPhoto = (r['photo'] ?? '').toString();
      });
    } catch (e) {
      setState(() => _recError = e.toString().replaceAll('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _recLoading = false);
    }
  }

  Future<void> _buy() async {
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      toast(context, 'یوزرنیم گیرنده را وارد کن', error: true);
      return;
    }
    final p = _priceFor(_months);
    if (p == null) return;
    try {
      final api = ref.read(apiProvider);
      final r = await api.premiumBuy(u, _months);
      final tx = (r is Map && r['transaction'] is Map) ? (r['transaction'] as Map).cast<String, dynamic>() : null;
      if (!mounted) return;
      if (tx == null) {
        toast(context, 'پاسخ سرور کامل نبود', error: true);
        return;
      }
      await runTxFlow(
        context,
        ref,
        tx: tx,
        title: 'پریمیوم ${_monthsLabel()}',
        subtitle: 'گیرنده: @$u — مبلغ: ${fmtTon(p.ton)} TON',
        type: OrderType.premium,
      );
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('ApiException: ', ''), error: true);
    }
  }

  dynamic _priceFor(int months) {
    if (_prices == null) return null;
    switch (months) {
      case 3:
        return _prices!.months3;
      case 6:
        return _prices!.months6;
      default:
        return _prices!.months12;
    }
  }

  String _monthsLabel() {
    final s = ref.read(settingsProvider).s;
    return _months == 3 ? s.months3 : _months == 6 ? s.months6 : s.months12;
  }

  Future<void> _openMultigift() async {
    final refCode = ref.read(settingsProvider).multigiftRef;
    final url = refCode.isEmpty ? 'tg://premium_multigift' : 'tg://premium_multigift?ref=$refCode';
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) toast(context, 'تلگرام باز نشد');
    } catch (_) {
      if (mounted) toast(context, 'تلگرام روی این گوشی نصب نیست', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(AppColors.yellow))),
            )
          else if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else ...[
            Text(
              'Telegram Premium — قیمت واقعی و لحظه‌ای',
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, color: Color(AppColors.textDim)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _planCard(3, s.months3),
                const SizedBox(width: 10),
                _planCard(6, s.months6),
                const SizedBox(width: 10),
                _planCard(12, s.months12),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(s.receiver, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(hintText: '@username یا یوزرنیم'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _recLoading ? null : _checkRecipient,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.card),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.5)),
                  ),
                  child: _recLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))
                      : const Text('بررسی', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 13, color: Color(AppColors.yellow))),
                ),
              ),
            ],
          ),
          if (_recError != null) ...[
            const SizedBox(height: 8),
            Text(_recError!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red))),
          ],
          if (_recName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(AppColors.green).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.green).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  if (_recPhoto!.isNotEmpty)
                    CircleAvatar(radius: 16, backgroundImage: NetworkImage(_recPhoto!))
                  else
                    const CircleAvatar(radius: 16, child: Icon(Icons.person_rounded, size: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_recName!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.check_circle_rounded, size: 17, color: Color(AppColors.green)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          YellowButton(
            label: '${s.buyPremium} — ${fmtTon(_priceFor(_months)?.ton)} TON',
            onTap: _priceFor(_months) != null ? _buy : null,
          ),
          const SizedBox(height: 12),
          GhostButton(label: s.premiumGiftInTg, onTap: _openMultigift),
          const SizedBox(height: 26),
        ],
      ),
    );
  }

  Widget _planCard(int months, String label) {
    final p = _priceFor(months);
    final active = _months == months;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _months = months),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? const Color(AppColors.yellow).withOpacity(0.12) : const Color(AppColors.card),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke),
              width: active ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  size: 26, color: Color(AppColors.yellow)),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                p == null ? '—' : '${fmtTon(p.ton)} TON',
                style: const TextStyle(
                    fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
