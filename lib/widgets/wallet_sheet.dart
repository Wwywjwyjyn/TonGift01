import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../providers/wallet_provider.dart';
import '../providers/core_providers.dart';
import 'common.dart';

/// شیت اتصال/وضعیت کیف پول — مثل دکمه Connect Wallet بالای صفحه
Future<void> showWalletSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _WalletSheet(),
  );
}

class _WalletSheet extends ConsumerStatefulWidget {
  const _WalletSheet();

  @override
  ConsumerState<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<_WalletSheet> {
  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final s = ref.watch(settingsProvider).s;
    final height = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.75),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.myWallet,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 6),
          if (wallet.isConnected) ...[
            _connectedView(wallet, s),
          ] else if (wallet.status == WalletStatus.connecting && wallet.pendingLink != null) ...[
            _pendingView(wallet, s),
          ] else ...[
            Text(
              s.fa
                  ? 'هر کدام از کیف پول‌های TON را انتخاب کن — بدون ثبت‌نام'
                  : 'Pick any TON wallet — no signup needed',
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: Color(AppColors.textDim)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: wallet.wallets.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Color(AppColors.yellow)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: wallet.wallets.length,
                      itemBuilder: (_, i) {
                        final w = wallet.wallets[i];
                        final name = (w.name ?? '').toString();
                        final img = (w.image ?? '').toString();
                        return GestureDetector(
                          onTap: () async {
                            await ref.read(walletProvider.notifier).connect(w);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(AppColors.card),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(AppColors.stroke)),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CachedNetworkImage(imageUrl: img, width: 40, height: 40,
                                  errorWidget: (_, __, ___) => const Icon(Icons.wallet_rounded, size: 36, color: Color(AppColors.yellow))),
                                const SizedBox(height: 6),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectedView(WalletState wallet, dynamic s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(AppColors.card),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(AppColors.green).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(AppColors.green), size: 18),
                  const SizedBox(width: 6),
                  Text(s.connected,
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 13, color: Color(AppColors.green))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wallet.address ?? '',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => copyText(context, wallet.address ?? ''),
                    icon: const Icon(Icons.copy_rounded, size: 17, color: Color(AppColors.textDim)),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                children: [
                  const Icon(Icons.diamond_outlined, size: 16, color: Color(AppColors.yellow)),
                  const SizedBox(width: 6),
                  Text('${fmtTon(wallet.balanceTon)} TON',
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 14, color: Color(AppColors.yellow))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ref.read(walletProvider.notifier).refreshBalance(),
                    child: const Icon(Icons.refresh_rounded, size: 18, color: Color(AppColors.textDim)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GhostButton(
          label: s.disconnect,
          color: const Color(AppColors.red),
          onTap: () async {
            await ref.read(walletProvider.notifier).disconnect();
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _pendingView(WalletState wallet, dynamic s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(color: Color(AppColors.yellow)),
        const SizedBox(height: 14),
        Text(s.waitingWallet, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5)),
        const SizedBox(height: 18),
        YellowButton(
          label: s.openWalletAgain,
          onTap: () => ref.read(walletProvider.notifier).reopenPendingLink(),
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: s.copy,
          onTap: () => copyText(context, wallet.pendingLink ?? ''),
        ),
        const SizedBox(height: 8),
        GhostButton(
          label: s.cancel,
          onTap: () async {
            await ref.read(walletProvider.notifier).cancelPending();
          },
        ),
      ],
    );
  }
}
