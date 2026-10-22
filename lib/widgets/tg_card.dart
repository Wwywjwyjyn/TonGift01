import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/gift_item.dart';
import '../providers/tg_provider.dart';
import '../providers/core_providers.dart';
import '../screens/tg/tg_connect_screen.dart';
import '../services/tg_api.dart';
import 'common.dart';

/// عکس استیکر گیفت — از بک‌اند خودت (با توکن دستگاه) با فال‌بک fragment
class TgStickerImage extends ConsumerWidget {
  final String? docId;
  final String? slug; // برای یکتاها: رندر fragment
  final double size;
  const TgStickerImage({super.key, this.docId, this.slug, this.size = 64});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(tgApiProvider);
    final hasSlug = slug != null && slug!.isNotEmpty;
    final url = hasSlug
        ? 'https://nft.fragment.com/gift/${slug!.toLowerCase()}.webp'
        : (docId != null && docId!.isNotEmpty ? api.stickerUrl(docId!) : '');

    Widget img;
    if (url.isEmpty) {
      img = Icon(Icons.card_giftcard_rounded, size: size * 0.5, color: const Color(AppColors.textDim));
    } else if (hasSlug) {
      // عکس عمومی fragment — بدون هدر
      img = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(api),
      );
    } else {
      img = Image.network(
        url,
        headers: api.imgHeaders(),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(api),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(AppColors.bg).withOpacity(0.6),
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          padding: const EdgeInsets.all(3),
          child: img,
        ),
      ),
    );
  }

  Widget _fallback(TgApi api) {
    if (docId != null && docId!.isNotEmpty) {
      return Image.network(
        api.stickerUrl(docId!),
        headers: api.imgHeaders(),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.card_giftcard_rounded, size: size * 0.5, color: const Color(AppColors.textDim)),
      );
    }
    return Icon(Icons.card_giftcard_rounded, size: size * 0.5, color: const Color(AppColors.textDim));
  }
}

/// کارت نوع گیفت در کاتالوگ مارکت تلگرام
class TgTypeCard extends StatelessWidget {
  final TgGiftType gift;
  final int? floorMin;
  final int? floorCount;
  final VoidCallback onTap;
  const TgTypeCard({super.key, required this.gift, this.floorMin, this.floorCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final showFloor = (floorMin != null && floorMin! > 0) || (floorCount != null && floorCount! > 0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppColors.stroke)),
        ),
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TgStickerImage(docId: gift.stickerDocId, size: 76),
                  if (gift.soldOut)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SOLD OUT',
                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFFF8A80)),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (gift.limited && gift.availabilityTotal != null)
                          MiniTag(
                            text: '${fmtCompact(gift.availabilityRemains ?? 0)}/${fmtCompact(gift.availabilityTotal!)}',
                            color: const Color(AppColors.blue),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              gift.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, size: 12, color: const Color(AppColors.yellow)),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    showFloor && floorMin != null && floorMin! > 0
                        ? '${fmtStars(floorMin!)}'
                        : fmtStars(gift.stars),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                  ),
                ),
                if (showFloor && floorCount != null && floorCount! > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· $floorCount',
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, color: Color(AppColors.textDim)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// کارت یک گیفت دست‌دوم دیگران
class TgListingCard extends StatelessWidget {
  final TgGift listing;
  final VoidCallback onTap;
  final VoidCallback? onBuy;
  const TgListingCard({super.key, required this.listing, required this.onTap, this.onBuy});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppColors.stroke)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TgStickerImage(slug: listing.slug, docId: listing.modelDocId, size: 84),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: MiniTag(text: '#${listing.num}', color: const Color(AppColors.blue)),
                  ),
                  if (listing.rarity is String && (listing.rarity as String).isNotEmpty)
                    Positioned(bottom: 0, left: 0, child: MiniTag(text: listing.rarity as String)),
                ],
              ),
            ),
            const SizedBox(height: 7),
            if (listing.model.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  listing.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: const Color(AppColors.yellow)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          fmtStars(listing.listPrice ?? 0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(AppColors.yellow)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onBuy != null)
                  GestureDetector(
                    onTap: onBuy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.yellow),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        'BUY',
                        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// کارت گیفت خودم در انبار تلگرام
class TgMyGiftCard extends StatelessWidget {
  final TgGift gift;
  final VoidCallback onTap;
  const TgMyGiftCard({super.key, required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gift.listed ? const Color(AppColors.yellow).withOpacity(0.55) : const Color(AppColors.stroke),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TgStickerImage(
                    slug: gift.isUnique ? gift.slug : null,
                    docId: gift.isUnique && gift.modelDocId.isNotEmpty ? gift.modelDocId : null,
                    size: 80,
                  ),
                  if (gift.listed)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: MiniTag(text: '★ ${fmtStars(gift.listPrice ?? 0)}'),
                    ),
                  if (gift.isUnique && gift.num > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: MiniTag(text: '#${gift.num}', color: const Color(AppColors.blue)),
                    ),
                  if (!gift.isUnique && gift.canUpgrade)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: MiniTag(text: 'UP', color: const Color(AppColors.green)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              gift.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, fontWeight: FontWeight.w700),
            ),
            if (gift.isUnique && gift.model.isNotEmpty)
              Text(
                gift.model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, color: Color(AppColors.textDim)),
              ),
          ],
        ),
      ),
    );
  }
}

/// پنل «اول تلگرام را وصل کن»
class TgConnectPrompt extends ConsumerWidget {
  const TgConnectPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).s;
    final sess = ref.watch(tgSessionProvider);
    String title = s.tgConnectFirst;
    String? sub;
    IconData icon = Icons.telegram_rounded;
    if (sess.phase == TgPhase.locked) {
      title = s.tgLockedMsg;
      icon = Icons.lock_rounded;
    } else if (sess.phase == TgPhase.needApi) {
      title = s.tgNeedApiSetup;
      sub = s.apiGateWhere;
      icon = Icons.vpn_key_rounded;
    }
    return EmptyPanel(
      icon: icon,
      title: title,
      subtitle: sub ?? s.tgConnectDesc,
      action: (sess.phase == TgPhase.disconnected)
          ? YellowButton(label: s.tgConnect, onTap: () => _openConnect(context))
          : null,
    );
  }

  void _openConnect(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TgConnectScreen()));
  }
}

/// تبدیل TgGift به GiftItem برای «مشاهده در تلگرام» با صفحه جزئیات موجود
GiftItem tgGiftToItem(TgGift g) {
  return GiftItem(
    address: g.ownerAddress,
    name: g.title,
    number: g.num > 0 ? g.num : null,
    model: g.model.isNotEmpty ? g.model : null,
    backdrop: g.backdrop.isNotEmpty ? g.backdrop : null,
    symbol: g.symbol.isNotEmpty ? g.symbol : null,
    currency: 'STARS',
    kind: 'owner',
    status: g.listed ? 'for_sale' : 'not_for_sale',
    imageUrl: g.fragmentImage(),
    raw: const {},
  );
}
