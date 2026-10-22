import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../providers/core_providers.dart';
import '../../providers/tg_provider.dart';
import '../../widgets/common.dart';

/// شیت اکانت تلگرام — کاربر، موجودی استارز، خروج
Future<void> showTgProfileSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TgProfileSheet(),
  );
}

class _TgProfileSheet extends ConsumerStatefulWidget {
  const _TgProfileSheet();

  @override
  ConsumerState<_TgProfileSheet> createState() => _TgProfileSheetState();
}

class _TgProfileSheetState extends ConsumerState<_TgProfileSheet> {
  bool _busy = false;

  Future<void> _openStarsInTelegram() async {
    // بخش استارز در اپ رسمی تلگرام
    final ok = await launchUrl(Uri.parse('tg://stars'), mode: LaunchMode.externalApplication);
    if (!ok) {
      // فال‌بک: کانال رسمی گیفت‌ها
      await launchUrl(Uri.parse('https://t.me/telegram'), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).s;
    final sess = ref.watch(tgSessionProvider);
    final u = sess.user;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(AppColors.yellow).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.4)),
                ),
                child: const Icon(Icons.telegram_rounded, size: 26, color: Color(AppColors.yellow)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (u?.name.isNotEmpty == true) ? u!.name : s.tgAccount,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
                    if (u != null && u.username.isNotEmpty)
                      Text('@${u.username}',
                          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, color: Color(AppColors.textDim))),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(tgSessionProvider.notifier).check();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const Divider(height: 22),
          // موجودی استارز
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(AppColors.yellow).withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(AppColors.yellow).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 22, color: Color(AppColors.yellow)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.tgStarsBalance,
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim))),
                    Text(
                      sess.stars == null ? '…' : '${fmtStars(sess.stars!)} ★',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openStarsInTelegram,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.yellow),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s.tgOpenMarket,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.tgTopUpHint,
            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim), height: 1.8),
          ),
          const SizedBox(height: 16),
          GhostButton(
            label: _busy ? s.loading : s.tgLogout,
            color: const Color(AppColors.red),
            onTap: _busy
                ? null
                : () async {
                    final s2 = ref.read(settingsProvider).s;
                    final go = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(AppColors.card),
                        title: Text(s2.tgLogout, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w800)),
                        content: Text(s2.tgLogoutConfirm, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(s2.cancel, style: const TextStyle(fontFamily: 'Vazirmatn')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(s2.confirm, style: const TextStyle(fontFamily: 'Vazirmatn', color: const Color(AppColors.red))),
                          ),
                        ],
                      ),
                    );
                    if (go != true || !mounted) return;
                    setState(() => _busy = true);
                    await ref.read(tgSessionProvider.notifier).logout();
                    if (!mounted) return;
                    Navigator.pop(context);
                    toast(context, '✓');
                  },
          ),
        ],
      ),
    );
  }
}
