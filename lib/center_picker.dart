import 'package:flutter/material.dart';

import 'charts.dart';
import 'store.dart';
import 'ui.dart';

/// اختيار جهة (معمل / معامل أخرى / منتجات أخرى) ببطاقات كبيرة سهلة الضغط.
class CenterPicker extends StatelessWidget {
  const CenterPicker({
    super.key,
    required this.ids,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.error = false,
  });

  final List<String> ids;
  final String? selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// يبرز البطاقات بالأحمر إذا المستخدم حاول يحفظ بدون اختيار.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final w = (box.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final id in ids)
              SizedBox(
                width: w,
                child: _CenterTile(
                  name: store.centerName(id),
                  icon: centerIcon(id),
                  color: centerColor(id),
                  selected: id == selected,
                  enabled: enabled,
                  error: error,
                  onTap: () => onChanged(id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CenterTile extends StatelessWidget {
  const _CenterTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.error,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? brand
        : error
        ? debtColor.withValues(alpha: .55)
        : appBorder;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: selected ? brand.withValues(alpha: .07) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 19, color: appInk),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: appInk,
                    ),
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: selected ? 1 : 0,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: brand,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
