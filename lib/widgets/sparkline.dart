import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/formatters.dart';

/// چارت خطی (خط شکسته) کف قیمت — با لمس کار می‌کند
/// خط روند سبز/قرمز، پرشدگی گرادیانی، خط‌راهنمای لمس با برچسب مقدار و تاریخ
class Sparkline extends StatefulWidget {
  final List<double> values;
  final List<int> timesMs; // هم‌طول values — برای برچسب زمان لمس
  final double height;
  final bool interactive;
  final Color? color;

  const Sparkline({
    super.key,
    required this.values,
    this.timesMs = const [],
    this.height = 120,
    this.interactive = true,
    this.color,
  });

  @override
  State<Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<Sparkline> {
  int? _hoverIndex;

  bool get _up {
    if (widget.values.length < 2) return true;
    return widget.values.last >= widget.values.first;
  }

  Color get _lineColor =>
      widget.color ?? (_up ? const Color(AppColors.green) : const Color(AppColors.red));

  @override
  Widget build(BuildContext context) {
    if (widget.values.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Icon(Icons.show_chart_rounded, size: 30, color: Colors.white.withOpacity(0.15)),
        ),
      );
    }

    return GestureDetector(
      onTapDown: widget.interactive ? (d) => _pick(d.localPosition) : null,
      onTapUp: widget.interactive ? (_) => setState(() => _hoverIndex = null) : null,
      onHorizontalDragStart: widget.interactive ? (d) => _pick(d.localPosition) : null,
      onHorizontalDragUpdate: widget.interactive ? (d) => _pick(d.localPosition) : null,
      onHorizontalDragEnd: widget.interactive ? (_) => setState(() => _hoverIndex = null) : null,
      child: SizedBox(
        height: widget.height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _SparkPainter(
            values: widget.values,
            hover: _hoverIndex,
            color: _lineColor,
          ),
          child: _hoverIndex != null ? _tooltip() : null,
        ),
      ),
    );
  }

  void _pick(Offset local) {
    final w = context.size?.width ?? 1;
    final ratio = (local.dx / w).clamp(0.0, 1.0);
    final i = (ratio * (widget.values.length - 1)).round();
    if (i != _hoverIndex) setState(() => _hoverIndex = i);
  }

  Widget _tooltip() {
    final i = _hoverIndex!.clamp(0, widget.values.length - 1);
    final v = widget.values[i];
    String when = '';
    if (widget.timesMs.length > i) {
      final d = DateTime.fromMillisecondsSinceEpoch(widget.timesMs[i]);
      when = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    }
    return LayoutBuilder(builder: (context, box) {
      final left = (_hoverIndex! / (widget.values.length - 1).clamp(1, 1 << 30)) * box.maxWidth;
      final align = left > box.maxWidth / 2;
      return Stack(children: [
        Positioned(
          top: 4,
          left: align ? null : math.min(left + 8, box.maxWidth - 110),
          right: align ? math.max(box.maxWidth - left + 8, 8) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xEE16161A),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _lineColor.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.diamond_outlined, size: 10, color: _lineColor),
                  const SizedBox(width: 4),
                  Text(
                    '${fmtTon(v)} TON',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _lineColor,
                    ),
                  ),
                ]),
                if (when.isNotEmpty)
                  Text(when, style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, color: Color(AppColors.textDim))),
              ],
            ),
          ),
        ),
      ]);
    });
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final int? hover;
  final Color color;

  _SparkPainter({required this.values, this.hover, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final padTop = 14.0;
    final padBottom = 6.0;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV) <= 0 ? 1.0 : (maxV - minV);
    final h = size.height - padTop - padBottom;

    Offset pt(int i) {
      final x = i / (values.length - 1) * size.width;
      final y = padTop + h - ((values[i] - minV) / span) * h;
      return Offset(x, y);
    }

    // خط شکسته (polyline) — نه منحنی
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }

    // پرشدگی گرادیانی زیر خط
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.22), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fill, fillPaint);

    // خط اصلی
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(line, linePaint);

    // نقطه آخر
    final last = pt(values.length - 1);
    canvas.drawCircle(last, 3.2, Paint()..color = color);
    canvas.drawCircle(last, 6.0, Paint()..color = color.withOpacity(0.25));

    // خط‌راهنمای لمس
    if (hover != null && hover! >= 0 && hover! < values.length) {
      final p = pt(hover!);
      final dash = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(p.dx, 10), Offset(p.dx, size.height), dash..filterQuality = FilterQuality.none);
      canvas.drawCircle(p, 4.4, Paint()..color = const Color(AppColors.bg));
      canvas.drawCircle(p, 4.4, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(p, 2.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.hover != hover || old.values != values || old.color != color;
}
