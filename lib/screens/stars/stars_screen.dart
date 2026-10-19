import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tx_flow.dart';

/// خرید Telegram Stars با TON — قیمت واقعی از API
class StarsScreen extends ConsumerStatefulWidget {
  const StarsScreen({super.key});

  @override
  ConsumerState<StarsScreen> createState() => _StarsScreenState();
}

class _StarsScreenState extends ConsumerState<StarsScreen> {
  int _qty = 100;
  final _userCtrl = TextEditingController();
  Timer? _debounce;

  bool _priceLoading = false;
  double? _tonPrice;
  String? _priceError;

  bool _recLoading = false;
  String? _recName;
  String? _recPhoto;
  String? _recError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _quote());
  }

  Future<void> _quote() async {
    setState(() {
      _priceLoading = true;
      _priceError = null;
    });
    try {
      final r = await ref.read(apiProvider).starsPrice(_qty);
      setState(() => _tonPrice = (r['ton'] as num?)?.toDouble());
    } catch (e) {
      setState(() {
        _priceError = e.toString().replaceAll('ApiException: ', '');
        _tonPrice = null;
      });
    } finally {
      if (mounted) setState(() => _priceLoading = false);
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
      final r = await ref.read(apiProvider).starsRecipient(u);
      setState(() {
        _recName = (r['name'] ?? '').toString();
        _recPhoto = (r['photo'] ?? '').toString();
      });
    } catch (e) {
      setState(() {
        _recError = e.toString().replaceAll('ApiException: ', '');
      });
    } finally {
      if (mounted) setState(() => _recLoading = false);
    }
  }

  void _setQty(int q) {
    setState(() => _qty = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _quote);
  }

  Future<void> _buy() async {
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      toast(context, 'یوزرنیم گیرنده را وارد کن', error: true);
      return;
    }
    if (_tonPrice == null) {
      toast(context, 'قیمت هنوز آماده نیست', error: true);
      return;
    }
    setState(() => _recLoading = true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.starsBuy(u, _qty);
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
        title: 'خرید $_qty استارز',
        subtitle: 'گیرنده: @$u — مبلغ: ${fmtTon(_tonPrice)} TON',
        type: OrderType.stars,
      );
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _recLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // تعداد استارز
          Text(s.quantity, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [50, 100, 250, 500, 1000]
                .map((q) => GestureDetector(
                      onTap: () => _setQty(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: _qty == q ? const Color(AppColors.yellow) : const Color(AppColors.card),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _qty == q ? const Color(AppColors.yellow) : const Color(AppColors.stroke),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 14, color: _qty == q ? const Color(0xFF111111) : const Color(AppColors.yellow)),
                            const SizedBox(width: 5),
                            Text(
                              '$q',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: _qty == q ? const Color(0xFF111111) : const Color(AppColors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final q = int.tryParse(v);
                    if (q != null && q > 0) _setQty(q);
                  },
                  decoration: InputDecoration(
                    hintText: '${s.starsCustom} — مثال: 4200',
                    prefixIcon: const Icon(Icons.edit_rounded, size: 17, color: Color(AppColors.textDim)),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // گیرنده
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
                    child: Text(_recName!,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.check_circle_rounded, size: 17, color: Color(AppColors.green)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          // مبلغ نهایی
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(AppColors.card),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(AppColors.stroke)),
            ),
            child: Row(
              children: [
                const Icon(Icons.diamond_outlined, size: 18, color: Color(AppColors.yellow)),
                const SizedBox(width: 8),
                Text(s.finalPrice,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: Color(AppColors.textDim))),
                const Spacer(),
                if (_priceLoading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))
                else
                  Text(
                    _tonPrice != null ? '${fmtTon(_tonPrice)} TON' : '—',
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 17, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                  ),
              ],
            ),
          ),
          if (_priceError != null) ...[
            const SizedBox(height: 8),
            Text(_priceError!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.red))),
          ],
          const SizedBox(height: 18),
          YellowButton(label: s.payNow, onTap: (_tonPrice != null && !_priceLoading) ? _buy : null),
          const SizedBox(height: 8),
          Center(
            child: Text(
              s.termsShort,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
            ),
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
