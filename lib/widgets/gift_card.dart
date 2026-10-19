import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../core/ton_utils.dart';
import '../models/gift_item.dart';

class GiftImage extends StatelessWidget {
  final GiftItem item;
  final double? width;
  final double? height;
  final BoxFit fit;
  const GiftImage({super.key, required this.item, this.width, this.height, this.fit = BoxFit.cover});

  Widget _err(BuildContext c) => CachedNetworkImage(
        imageUrl: item.imageFallback,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (_, __, ___) => _placeholder(),
      );

  Widget _placeholder() => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF23232B), Color(0xFF15151A)],
          ),
        ),
        child: const Icon(Icons.card_giftcard_rounded, color: Color(AppColors.textDim), size: 34),
      );

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: item.effectiveImage,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: const Color(AppColors.card),
        child: const Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _err(context),
    );
  }
}

class GiftCard extends StatelessWidget {
  final GiftItem item;
  final VoidCallback onTap;
  const GiftCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isStars = item.currency.toUpperCase() == 'STARS';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(AppColors.stroke)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GiftImage(item: item),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _kindBadge(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  // آیدی گیفت زیر عکس
                  Text(
                    item.slug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10.5, color: Color(AppColors.textDim)),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        isStars ? Icons.star_rounded : Icons.diamond_outlined,
                        size: 14,
                        color: const Color(AppColors.yellow),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isStars
                              ? '${fmtStars(parseNumFlexible(item.raw['min_bid']) ?? parseNumFlexible(item.raw['price']) ?? 0)} ★'
                              : item.kind == 'rent'
                                  ? '${fmtTon(item.pricePerDayTon)}/روز'
                                  : item.priceTon != null
                                      ? '${fmtTon(item.priceTon)} TON'
                                      : '—',
                          style: const TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(AppColors.yellow),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindBadge() {
    final String label;
    final Color c;
    if (item.kind == 'rent') {
      label = 'اجاره';
      c = const Color(AppColors.blue);
    } else if (item.status == 'for_sale') {
      label = 'فروش';
      c = const Color(AppColors.yellow);
    } else {
      label = 'مالک';
      c = const Color(AppColors.green);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}
