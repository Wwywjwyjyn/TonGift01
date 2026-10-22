import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/strings.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tx_flow.dart';

/// استارز و پریمیوم — دو بخش در یک صفحه (مثل مرجع):
/// سوییچ بالای صفحه + کارت‌های جمع‌وجور با قیمت واقعی TON از API
class StarsPremiumScreen extends ConsumerStatefulWidget {
  const StarsPremiumScreen({super.key});

  @override
  ConsumerState<StarsPremiumScreen> createState() => _StarsPremiumScreenState();
}

class _StarsPremiumScreenState extends ConsumerState<StarsPremiumScreen> {
  bool _starsTab = true; // true=استارز، false=پریمیوم

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // سوییچ بخش — استارز | پریمیوم
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(AppColors.surface),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(AppColors.stroke)),
            ),
            child: Row(
              children: [
                _segment(
                  icon: Icons.star_rounded,
                  label: s.stars,
                  active: _starsTab,
                  onTap: () => setState(() => _starsTab = true),
                ),
                const SizedBox(width: 4),
                _segment(
                  icon: Icons.workspace_premium_rounded,
                  label: s.premium,
                  active: !_starsTab,
                  onTap: () => setState(() => _starsTab = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _starsTab
                ? _StarsSection(key: const ValueKey('stars'), s: s)
                : _PremiumSection(key: const ValueKey('premium'), s: s),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _segment({required IconData icon, required String label, required bool active, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(AppColors.yellow) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? const Color(0xFF111111) : const Color(AppColors.textDim)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active ? const Color(0xFF111111) : const Color(AppColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// استارز
// ============================================================
class _StarsSection extends ConsumerStatefulWidget {
  final S s;
  const _StarsSection({super.key, required this.s});

  @override
  ConsumerState<_StarsSection> createState() => _StarsSectionState();
}

class _StarsSectionState extends ConsumerState<_StarsSection> {
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

  static const _presets = [50, 100, 150, 250, 500, 1000, 2500, 5000];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _quote());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userCtrl.dispose();
    super.dispose();
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
    final s = widget.s;
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      setState(() => _recError = s.enterUsername);
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
    final s = widget.s;
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      toast(context, s.enterUsername, error: true);
      return;
    }
    if (_tonPrice == null) {
      toast(context, s.priceNotReady, error: true);
      return;
    }
    setState(() => _recLoading = true);
    try {
      final api = ref.read(apiProvider);
      final r = await api.starsBuy(u, _qty);
      final tx = (r is Map && r['transaction'] is Map) ? (r['transaction'] as Map).cast<String, dynamic>() : null;
      if (!mounted) return;
      if (tx == null) {
        toast(context, s.serverResponseIncomplete, error: true);
        return;
      }
      await runTxFlow(
        context,
        ref,
        tx: tx,
        title: '${widget.s.stars} $_qty',
        subtitle: '@$u — ${fmtTon(_tonPrice)} TON',
        type: OrderType.stars,
      );
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('ApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _recLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // هدر
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2408), Color(AppColors.card)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(AppColors.yellow).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.star_rounded, size: 26, color: Color(AppColors.yellow)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.stars} ★',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.termsShort,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // تعداد
        Text(s.quantity, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _presets
              .map((q) => GestureDetector(
                    onTap: () => _setQty(q),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: _qty == q ? const Color(AppColors.yellow) : const Color(AppColors.card),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _qty == q ? const Color(AppColors.yellow) : const Color(AppColors.stroke),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 13, color: _qty == q ? const Color(0xFF111111) : const Color(AppColors.yellow)),
                          const SizedBox(width: 4),
                          Text(
                            '$q',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: _qty == q ? const Color(0xFF111111) : const Color(AppColors.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          keyboardType: TextInputType.number,
          onChanged: (v) {
            final q = int.tryParse(v);
            if (q != null && q > 0) _setQty(q);
          },
          decoration: InputDecoration(
            hintText: '${s.starsCustom} — 4200',
            prefixIcon: const Icon(Icons.edit_rounded, size: 16, color: Color(AppColors.textDim)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        // گیرنده
        Text(s.receiver, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(hintText: '@username'),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _recLoading ? null : _checkRecipient,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(AppColors.card),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.5)),
                ),
                child: _recLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))
                    : Text(s.check, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(AppColors.yellow))),
              ),
            ),
          ],
        ),
        if (_recError != null) ...[
          const SizedBox(height: 8),
          Text(_recError!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.red))),
        ],
        if (_recName != null) ...[
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(AppColors.green).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(AppColors.green).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                if (_recPhoto!.isNotEmpty)
                  CircleAvatar(radius: 15, backgroundImage: NetworkImage(_recPhoto!))
                else
                  const CircleAvatar(radius: 15, child: Icon(Icons.person_rounded, size: 17)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(_recName!,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.check_circle_rounded, size: 16, color: Color(AppColors.green)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        // مبلغ نهایی
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(AppColors.card),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(AppColors.stroke)),
          ),
          child: Row(
            children: [
              const Icon(Icons.diamond_outlined, size: 17, color: Color(AppColors.yellow)),
              const SizedBox(width: 8),
              Text(s.finalPrice,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: Color(AppColors.textDim))),
              const Spacer(),
              if (_priceLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)))
              else
                Text(
                  _tonPrice != null ? '${fmtTon(_tonPrice)} TON' : '—',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                ),
            ],
          ),
        ),
        if (_priceError != null) ...[
          const SizedBox(height: 8),
          Text(_priceError!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.red))),
        ],
        const SizedBox(height: 14),
        YellowButton(label: s.payNow, onTap: (_tonPrice != null && !_priceLoading) ? _buy : null),
      ],
    );
  }
}

// ============================================================
// پریمیوم
// ============================================================
class _PremiumSection extends ConsumerStatefulWidget {
  final S s;
  const _PremiumSection({super.key, required this.s});

  @override
  ConsumerState<_PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends ConsumerState<_PremiumSection> {
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

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
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

  PriceInfo? _priceFor(int months) {
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

  String _monthsLabel(int m) => m == 3 ? widget.s.months3 : m == 6 ? widget.s.months6 : widget.s.months12;

  Future<void> _checkRecipient() async {
    final s = widget.s;
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      setState(() => _recError = s.enterUsername);
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
    final s = widget.s;
    final u = _userCtrl.text.trim().replaceAll('@', '');
    if (u.isEmpty) {
      toast(context, s.enterUsername, error: true);
      return;
    }
    final p = _priceFor(_months);
    if (p == null) {
      toast(context, s.priceNotReady, error: true);
      return;
    }
    try {
      final api = ref.read(apiProvider);
      final r = await api.premiumBuy(u, _months);
      final tx = (r is Map && r['transaction'] is Map) ? (r['transaction'] as Map).cast<String, dynamic>() : null;
      if (!mounted) return;
      if (tx == null) {
        toast(context, s.serverResponseIncomplete, error: true);
        return;
      }
      await runTxFlow(
        context,
        ref,
        tx: tx,
        title: '${s.premium} ${_monthsLabel(_months)}',
        subtitle: '@$u — ${fmtTon(p.ton)} TON',
        type: OrderType.premium,
      );
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceAll('ApiException: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // هدر
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A2233), Color(AppColors.card)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4DA3FF).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(AppColors.blue).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.workspace_premium_rounded, size: 26, color: Color(AppColors.blue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telegram Premium',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.termsShort,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(26),
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)),
            ),
          )
        else if (_error != null)
          ErrorPanel(message: _error!, onRetry: _load)
        else ...[
          // کارت‌های سه‌گانه پلن — قیمت واقعی API
          Row(
            children: [3, 6, 12].map((m) {
              final p = _priceFor(m);
              final active = _months == m;
              final perMonth = p == null ? null : p.ton / m;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _months = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.only(left: m == 3 ? 0 : 5, right: m == 12 ? 0 : 5),
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
                    decoration: BoxDecoration(
                      color: active ? const Color(AppColors.yellow).withOpacity(0.10) : const Color(AppColors.card),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? const Color(AppColors.yellow) : const Color(AppColors.stroke),
                        width: active ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // بج بهترین ارزش برای ۱۲ ماهه
                        if (m == 12)
                          Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(AppColors.green).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.bestValue,
                              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(AppColors.green)),
                            ),
                          )
                        else
                          const SizedBox(height: 18),
                        Text(
                          _monthsLabel(m),
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: active ? const Color(AppColors.yellow) : const Color(AppColors.textDim),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          p == null ? '—' : '${fmtTon(p.ton)}',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: active ? const Color(AppColors.yellow) : const Color(AppColors.text),
                          ),
                        ),
                        Text(
                          'TON',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 9.5,
                            color: active ? const Color(AppColors.yellow).withOpacity(0.8) : const Color(AppColors.textDim),
                          ),
                        ),
                        if (perMonth != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${fmtTon(perMonth)} TON ${s.perMonth}',
                            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9, color: Color(AppColors.textDim)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // گیرنده
          Text(s.receiver, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(hintText: '@username'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _recLoading ? null : _checkRecipient,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.card),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(AppColors.blue).withOpacity(0.5)),
                  ),
                  child: _recLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.blue)))
                      : Text(s.check, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(AppColors.blue))),
                ),
              ),
            ],
          ),
          if (_recError != null) ...[
            const SizedBox(height: 8),
            Text(_recError!, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: Color(AppColors.red))),
          ],
          if (_recName != null) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(AppColors.green).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(AppColors.green).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  if (_recPhoto!.isNotEmpty)
                    CircleAvatar(radius: 15, backgroundImage: NetworkImage(_recPhoto!))
                  else
                    const CircleAvatar(radius: 15, child: Icon(Icons.person_rounded, size: 17)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(_recName!,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(AppColors.green)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // مبلغ نهایی
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(AppColors.card),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(AppColors.stroke)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 17, color: Color(AppColors.blue)),
                const SizedBox(width: 8),
                Text(s.finalPrice,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: Color(AppColors.textDim))),
                const Spacer(),
                Builder(builder: (_) {
                  final p = _priceFor(_months);
                  return Text(
                    p == null ? '—' : '${fmtTon(p.ton)} TON',
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          YellowButton(label: s.buyPremium, onTap: _prices != null ? _buy : null),
        ],
      ],
    );
  }
}
