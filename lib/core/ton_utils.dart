/// ابزار آدرس TON — تبدیل raw به friendly و مقایسه امن
import 'dart:convert';

int _crc16(List<int> data) {
  int crc = 0xFFFF;
  const int poly = 0x1021;
  for (final b in data) {
    crc ^= b << 8;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ poly) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc & 0xFFFF;
}

/// 0:hex یا -1:hex -> EQ…/UQ… (base64url با CRC)
String tonFriendly(String raw) {
  try {
    if (raw.contains(':')) {
      final wc = int.parse(raw.split(':')[0]);
      final hex = raw.split(':')[1].toLowerCase();
      final re = RegExp(r'^[0-9a-f]{64}$');
      if (re.hasMatch(hex)) {
        final tag = wc == -1 ? 0xff : (wc != 0 ? 0x51 : 0x11);
        final payload = <int>[tag, ...List<int>.generate(32, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16))];
        final crc = _crc16(payload);
        final full = <int>[...payload, (crc >> 8) & 0xff, crc & 0xff];
        return base64Url.encode(full).replaceAll('=', '');
      }
    }
    return raw;
  } catch (_) {
    return raw;
  }
}

/// آیا دو رشته آدرس یک کیف پول‌اند؟ (raw/friendly و برعکس)
bool tonSameAddress(String? a, String? b) {
  if (a == null || b == null || a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  final fa = tonFriendly(a);
  final fb = tonFriendly(b);
  return fa == fb;
}

/// نمایش کوتاه آدرس
String tonShort(String? a) {
  if (a == null || a.isEmpty) return '';
  if (a.length <= 12) return a;
  return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
}

/// پارس عدد از num یا String (قیمت‌های API گاهی String هستند)
num? parseNumFlexible(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  final s = v.toString().trim();
  return num.tryParse(s);
}
