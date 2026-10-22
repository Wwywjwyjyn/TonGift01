import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/theme.dart';

class YellowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final double height;
  const YellowButton({
    super.key,
    required this.label,
    this.onTap,
    this.busy = false,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy || onTap == null ? null : onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0x33FFD600) : const Color(AppColors.yellow),
          borderRadius: BorderRadius.circular(14),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF111111)),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF111111),
                ),
              ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const GhostButton({super.key, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color ?? const Color(AppColors.stroke)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color ?? const Color(AppColors.text),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ChipTag extends StatelessWidget {
  final String label;
  final String? value;
  final Color? color;
  const ChipTag({super.key, required this.label, this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? const Color(AppColors.yellow)).withOpacity( 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (color ?? const Color(AppColors.yellow)).withOpacity( 0.35)),
      ),
      child: Text(
        value == null || value!.isEmpty ? label : '$label: $value',
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(AppColors.yellow),
        ),
      ),
    );
  }
}

class LoadingGrid extends StatelessWidget {
  final int count;
  final int columns;
  const LoadingGrid({super.key, this.count = 6, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.76,
      ),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: const Color(AppColors.card),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(AppColors.yellow)),
          ),
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData icon;
  const EmptyPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(AppColors.textDim)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: Color(AppColors.textDim), height: 1.8),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  const ErrorPanel({super.key, required this.message, this.onRetry, this.retryLabel = 'Retry / تلاش مجدد'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(AppColors.red)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, height: 1.9),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              GhostButton(label: retryLabel, onTap: onRetry, color: const Color(AppColors.yellow)),
            ],
          ],
        ),
      ),
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
      backgroundColor: error ? const Color(AppColors.red).withOpacity( 0.92) : const Color(AppColors.card),
      duration: const Duration(milliseconds: 2600),
    ),
  );
}

void copyText(BuildContext context, String text, [String? message]) {
  Clipboard.setData(ClipboardData(text: text));
  toast(context, message ?? 'Copied ✓ | کپی شد ✓');
}

/// تگ کوچک برای مشخصات (مدل/بک‌گراند/سمبل)
class MiniTag extends StatelessWidget {
  final String text;
  final Color? color;
  const MiniTag({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(AppColors.textDim);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

/// بج نشانگر تعداد (برای سبد خرید و فیلترها)
class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(AppColors.yellow), shape: BoxShape.circle),
      child: Text(
        '$count',
        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF111111)),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const InfoRow({super.key, required this.label, required this.value, this.copyable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(AppColors.card),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(AppColors.stroke)),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, color: Color(AppColors.textDim))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () => copyText(context, value),
              child: const Icon(Icons.copy_rounded, size: 16, color: Color(AppColors.textDim)),
            ),
        ],
      ),
    );
  }
}

String prettyJsonError(Object e) => e.toString().replaceAll('ApiException: ', '');
