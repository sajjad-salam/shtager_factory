// رسوم بيانية بسيطة مبنية بدون مكتبات خارجية.
// كل رسم يدعم الضغط لعرض التفاصيل، ويحمل تسميات مباشرة حتى ما يعتمد على اللون وحده.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'reports.dart';
import 'store.dart';
import 'ui.dart';

// ───────────── الألوان (لوحة مفحوصة لعمى الألوان، ترتيب ثابت) ─────────────

const _factoryPalette = [
  Color(0xFF2A78D6), // أزرق
  Color(0xFF1BAF7A), // فيروزي
  Color(0xFF6250D6), // بنفسجي
  Color(0xFF008300), // أخضر
];
const otherFactoriesColor = Color(0xFFEDA100); // أصفر
const otherProductsColor = Color(0xFFE87BA4); // وردي
const salesSeriesColor = Color(0xFF2A78D6);
const purchasesSeriesColor = Color(0xFFEB6834);
const _grid = Color(0xFFE1E0D9);
const _baseline = Color(0xFFC3C2B7);

/// لون الجهة يتبعها دائماً (ما يتغير حسب الترتيب أو الفلتر).
Color centerColor(String id) {
  if (id == kOtherFactoriesId) return otherFactoriesColor;
  if (id == kOtherProductsId) return otherProductsColor;
  final i = AppStore.instance.factories.indexWhere((f) => f.id == id);
  return _factoryPalette[(i < 0 ? 0 : i) % _factoryPalette.length];
}

IconData centerIcon(String id) => switch (id) {
  kOtherFactoriesId => Icons.local_shipping_outlined,
  kOtherProductsId => Icons.category_outlined,
  _ => Icons.factory_outlined,
};

String centerHint(String id) => switch (id) {
  kOtherFactoriesId => 'شتايكر تشتريه من معامل غيرك وتبيعه',
  kOtherProductsId => 'فوم، ماستيك، زفت وكل شي غير الشتايكر',
  _ => 'شتايكر من إنتاج هذا المعمل',
};

String _pct(double v) => '${(v * 100).round()}%';

// ───────────── بطاقة الرسم ─────────────

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(AppRadius.tile),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: appInk,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: appMuted),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class ChartEmpty extends StatelessWidget {
  const ChartEmpty(this.text, {super.key, this.icon = Icons.insights_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 34),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: appMuted, fontSize: 13),
        ),
      ],
    ),
  );
}

// ───────────── مفتاح لون صغير ─────────────

class LegendDot extends StatelessWidget {
  const LegendDot(this.color, {super.key, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

// ───────────── الدونات ─────────────

class ChartSegment {
  const ChartSegment(this.label, this.value, this.color, {this.sub});

  final String label;
  final double value;
  final Color color;
  final String? sub;
}

/// دونات مع قائمة تسميات. الضغط على قطعة أو سطر يبرزها ويعرض قيمتها بالوسط.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    this.size = 150,
  });

  final List<ChartSegment> segments;
  final String centerLabel;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _selected;

  List<ChartSegment> get _visible =>
      widget.segments.where((s) => s.value > 0).toList();

  void _tapAt(Offset local) {
    final segs = _visible;
    final total = segs.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final c = Offset(widget.size / 2, widget.size / 2);
    final d = local - c;
    final r = d.distance;
    if (r < widget.size * .28 || r > widget.size / 2 + 6) {
      setState(() => _selected = null);
      return;
    }
    // الزاوية تبدأ من الأعلى وتدور مع عقارب الساعة.
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    var acc = 0.0;
    for (var i = 0; i < segs.length; i++) {
      acc += segs[i].value / total * 2 * math.pi;
      if (a <= acc) {
        setState(() => _selected = _selected == i ? null : i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final segs = _visible;
    final total = segs.fold<double>(0, (s, e) => s + e.value);
    final sel = _selected != null && _selected! < segs.length
        ? segs[_selected!]
        : null;
    final donut = GestureDetector(
      onTapUp: (d) => _tapAt(d.localPosition),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            painter: _DonutPainter(
              segs,
              progress: t,
              selected: _selected,
              background: appSurface,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sel?.label ?? widget.centerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: appMuted),
                    ),
                    FittedBox(
                      child: Text(
                        fmtCompact(sel?.value ?? total),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: appInk,
                        ),
                      ),
                    ),
                    if (sel != null)
                      Text(
                        _pct(sel.value / total),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: appMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final legend = Column(
      children: [
        for (var i = 0; i < segs.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selected = _selected == i ? null : i),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _selected == null || _selected == i ? 1 : .45,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    LegendDot(segs[i].color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        segs[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: appInk,
                        ),
                      ),
                    ),
                    Text(
                      _pct(segs[i].value / total),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: appInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 330) {
          return Column(children: [donut, const SizedBox(height: 12), legend]);
        }
        return Row(
          children: [
            donut,
            const SizedBox(width: 18),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(
    this.segs, {
    required this.progress,
    required this.selected,
    required this.background,
  });

  final List<ChartSegment> segs;
  final double progress;
  final int? selected;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segs.fold<double>(0, (s, e) => s + e.value);
    final stroke = size.width * .15;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke / 2 - 3,
    );
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = _grid,
      );
      return;
    }
    // فراغ ٢px بين القطع.
    final gap = segs.length > 1 ? 2 / rect.width * 2 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < segs.length; i++) {
      final sweep = segs[i].value / total * 2 * math.pi * progress;
      final isSel = selected == i;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? stroke + 6 : stroke
        ..color = selected == null || isSel
            ? segs[i].color
            : segs[i].color.withValues(alpha: .35);
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.selected != selected || old.segs != segs;
}

// ───────────── أعمدة مرتبة (الأكثر/الأنشط) ─────────────

class RankedBars extends StatelessWidget {
  const RankedBars({
    super.key,
    required this.items,
    required this.color,
    this.max = 5,
    this.valueText,
    this.onTap,
  });

  final List<RankItem> items;
  final Color Function(RankItem item) color;
  final int max;
  final String Function(RankItem item)? valueText;
  final void Function(RankItem item)? onTap;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(max).toList();
    final top = shown.isEmpty ? 1.0 : shown.first.value.abs();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap == null ? null : () => onTap!(shown[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? brand : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? Colors.white : appMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shown[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: appInk,
                                ),
                              ),
                            ),
                            Text(
                              valueText?.call(shown[i]) ??
                                  fmtMoney(shown[i].value),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: appInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _AnimatedBar(
                          fraction: top <= 0 ? 0 : shown[i].value.abs() / top,
                          color: color(shown[i]),
                        ),
                        if (shown[i].sub != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            shown[i].sub!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: appMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 8,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
    ),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1).toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: math.max(f, .02),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}

// ───────────── مقارنة الأرباح (أعمدة موجبة/سالبة) ─────────────

class ProfitCompareChart extends StatelessWidget {
  const ProfitCompareChart({super.key, required this.stats, this.onTap});

  final List<CenterStats> stats;
  final void Function(String centerId)? onTap;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final top = stats.fold<double>(0, (m, s) => math.max(m, s.profit.abs()));
    final hasLoss = stats.any((s) => s.profit < 0);
    return Column(
      children: [
        for (final s in stats)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap == null ? null : () => onTap!(s.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      LegendDot(centerColor(s.id)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.centerName(s.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: appInk,
                          ),
                        ),
                      ),
                      _ProfitValue(s.profit),
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: appMuted,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 12,
                    child: _DivergingBar(
                      value: top <= 0 ? 0 : s.profit / top,
                      color: centerColor(s.id),
                      split: hasLoss,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.isEmpty
                        ? 'ماكو حركة بهذه الفترة'
                        : 'مبيعات ${fmtCompact(s.sales)} · مشتريات ${fmtCompact(s.purchases)}',
                    style: const TextStyle(fontSize: 11, color: appMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfitValue extends StatelessWidget {
  const _ProfitValue(this.v);

  final double v;

  @override
  Widget build(BuildContext context) {
    final neg = v < -0.0001;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          neg ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          size: 16,
          color: neg ? debtColor : okColor,
        ),
        const SizedBox(width: 4),
        Text(
          fmtMoney(v),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: neg ? debtColor : okColor,
          ),
        ),
      ],
    );
  }
}

/// عمود يبدأ من خط الصفر: الربح يمشي باتجاه، والخسارة بالاتجاه المعاكس.
class _DivergingBar extends StatelessWidget {
  const _DivergingBar({
    required this.value,
    required this.color,
    required this.split,
  });

  /// من -1 إلى 1
  final double value;
  final Color color;

  /// إذا توجد خسارة، خط الصفر بالنص.
  final bool split;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.clamp(-1, 1).toDouble()),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => CustomPaint(
      painter: _DivergingPainter(
        v,
        color,
        split,
        Directionality.of(context) == TextDirection.rtl,
      ),
    ),
  );
}

class _DivergingPainter extends CustomPainter {
  _DivergingPainter(this.v, this.color, this.split, this.rtl);

  final double v;
  final Color color;
  final bool split;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.drawRRect(track, Paint()..color = Colors.white);
    // بالعربي الموجب يمشي من اليمين لليسار.
    final dir = rtl ? -1.0 : 1.0;
    final zero = split ? size.width / 2 : (rtl ? size.width : 0.0);
    final span = split ? size.width / 2 : size.width;
    final end = zero + dir * v * span;
    if (v.abs() > 0.0001) {
      final rect = Rect.fromLTRB(
        math.min(zero, end),
        0,
        math.max(zero, end),
        size.height,
      );
      final paint = Paint()
        ..color = v < 0 ? color.withValues(alpha: .45) : color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
    if (split) {
      canvas.drawRect(
        Rect.fromLTWH(zero - .75, -2, 1.5, size.height + 4),
        Paint()..color = _baseline,
      );
    }
  }

  @override
  bool shouldRepaint(_DivergingPainter old) =>
      old.v != v || old.color != color || old.split != split;
}

// ───────────── الاتجاه الشهري ─────────────

/// أعمدة مزدوجة (مبيعات/مشتريات) لآخر ٦ أشهر. الضغط على شهر يعرض أرقامه.
class MonthlyTrendChart extends StatefulWidget {
  const MonthlyTrendChart({super.key, required this.months, this.height = 150});

  final List<MonthPoint> months;
  final double height;

  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart> {
  late int _selected = widget.months.length - 1;

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final top = months.fold<double>(
      0,
      (m, p) => math.max(m, math.max(p.sales, p.purchases)),
    );
    final scaleMax = _niceMax(top);
    final sel = months[_selected.clamp(0, months.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // قراءة الشهر المختار
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Container(
            key: ValueKey(_selected),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${arabicMonths[sel.month.month - 1]} ${sel.month.year}',
                        style: const TextStyle(fontSize: 12, color: appMuted),
                      ),
                      _ProfitValue(sel.profit),
                    ],
                  ),
                ),
                _miniStat('مبيعات', sel.sales, salesSeriesColor),
                const SizedBox(width: 14),
                _miniStat('مشتريات', sel.purchases, purchasesSeriesColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: widget.height,
          // بالعربي الرسم معكوس: المحور يمين وأقدم شهر يمين.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_axis(scaleMax), _axis(scaleMax / 2), _axis(0)],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: 22,
                      child: CustomPaint(painter: _GridPainter()),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < months.length; i++)
                          Expanded(
                            child: _MonthColumn(
                              point: months[i],
                              max: scaleMax,
                              selected: i == _selected,
                              onTap: () => setState(() => _selected = i),
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
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LegendDot(salesSeriesColor),
            SizedBox(width: 6),
            Text('المبيعات', style: TextStyle(fontSize: 12, color: appInk)),
            SizedBox(width: 18),
            LegendDot(purchasesSeriesColor),
            SizedBox(width: 6),
            Text('المشتريات', style: TextStyle(fontSize: 12, color: appInk)),
          ],
        ),
      ],
    );
  }

  Widget _axis(double v) => Text(
    v == 0 ? '0' : fmtCompact(v),
    maxLines: 1,
    style: const TextStyle(fontSize: 9, color: appMuted),
  );

  Widget _miniStat(String label, double v, Color c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          LegendDot(c, size: 8),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: appMuted)),
        ],
      ),
      Text(
        fmtCompact(v),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: appInk,
        ),
      ),
    ],
  );

  static double _niceMax(double v) {
    if (v <= 0) return 1;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
      if (v <= m * mag) return m * mag;
    }
    return 10 * mag;
  }
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.point,
    required this.max,
    required this.selected,
    required this.onTap,
  });

  final MonthPoint point;
  final double max;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: selected ? brand.withValues(alpha: .06) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bar(point.sales / max, salesSeriesColor),
                  const SizedBox(width: 2),
                  _bar(point.purchases / max, purchasesSeriesColor),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 22,
            child: Center(
              child: Text(
                shortArabicMonths[point.month.month - 1],
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? appInk : appMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bar(double f, Color c) => Flexible(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 12),
      child: LayoutBuilder(
        builder: (context, box) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: f.clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Container(
            height: v <= 0 ? 0 : math.max(3, v * box.maxHeight),
            decoration: BoxDecoration(
              color: c,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (final y in [4.0, (size.height + 4) / 2]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = _baseline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ───────────── اختيار الفترة ─────────────

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ReportPeriod value;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      children: [
        for (final p in ReportPeriod.values)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p == value ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: p == value
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  p.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: p == value ? FontWeight.w700 : FontWeight.w500,
                    color: p == value ? brand : appMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
