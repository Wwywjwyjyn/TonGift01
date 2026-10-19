import 'package:intl/intl.dart';

final NumberFormat _nf2 = NumberFormat.decimalPattern();
final NumberFormat _irt = NumberFormat.decimalPattern();

/// نانو TON -> TON
double nanoToTon(dynamic nano) {
  if (nano == null) return 0;
  final v = BigInt.tryParse(nano.toString()) ?? BigInt.zero;
  return v / BigInt.from(1000000000);
}

/// نمایش قیمت TON
String fmtTon(num? v, {int digits = 3}) {
  if (v == null || v == 0) return '0';
  final s = v.toStringAsFixed(digits);
  final trimmed = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return trimmed;
}

/// قیمت استارز
String fmtStars(num v) => _nf2.format(v.round());

/// قیمت ریالی
String fmtIrt(num v) => _irt.format(v.round());

/// حجم‌های بزرگ کالکشن
String fmtCompact(num v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String shortAddr(String? a) {
  if (a == null || a.isEmpty) return '';
  return '${a.substring(0, a.length > 10 ? 6 : a.length)}…${a.substring(a.length - 4)}';
}

String? attrValue(List attrs, String type) {
  for (final a in attrs) {
    if (a is Map &&
        (a['trait_type']?.toString().toLowerCase() == type.toLowerCase())) {
      return a['value']?.toString();
    }
  }
  return null;
}

String timeAgoFa(DateTime t, bool fa) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return fa ? 'همین حالا' : 'now';
  if (d.inMinutes < 60) return fa ? '${d.inMinutes} دقیقه پیش' : '${d.inMinutes}m ago';
  if (d.inHours < 24) return fa ? '${d.inHours} ساعت پیش' : '${d.inHours}h ago';
  return fa ? '${d.inDays} روز پیش' : '${d.inDays}d ago';
}
