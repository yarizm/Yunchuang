import 'package:flutter/material.dart';

import '../models/reading_background.dart';

/// 正文纸张选择器：一排预设色卡，外加一个自定义底色。
class ReaderPaperPicker extends StatelessWidget {
  final ReaderPaper selected;

  /// 上次用过的自定义底色，没有就传 null。
  ///
  /// 单独传进来，是因为 [selected] 在选中预设时不带自定义色。偏好里那个
  /// ARGB 是**故意**留着的（见 `PreferencesNotifier.updateReaderPaper`），
  /// 只看 [selected] 的话它就取不到了：调了个满意的颜色、临时切去米白、
  /// 再点回自定义，色卡和取色盘都会从头开始。
  final Color? lastCustomColor;

  final ValueChanged<ReaderPaper> onChanged;

  const ReaderPaperPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.lastCustomColor,
  });

  @override
  Widget build(BuildContext context) {
    final isCustom = selected.id == ReaderPaper.customId;
    final remembered =
        (isCustom ? selected.background : null) ?? lastCustomColor;
    final swatchColor = remembered ?? Theme.of(context).colorScheme.surface;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final paper in ReaderPaper.presets)
          _PaperSwatch(
            paper: paper,
            selected: paper.id == selected.id,
            onTap: () => onChanged(paper),
          ),
        _PaperSwatch(
          paper: ReaderPaper.custom(swatchColor),
          label: '自定义',
          selected: isCustom,
          showEditBadge: true,
          onTap: () async {
            final picked = await showDialog<Color>(
              context: context,
              builder: (_) => _PaperColorDialog(initial: swatchColor),
            );
            if (picked != null) onChanged(ReaderPaper.custom(picked));
          },
        ),
      ],
    );
  }
}

class _PaperSwatch extends StatelessWidget {
  final ReaderPaper paper;
  final String? label;
  final bool selected;
  final bool showEditBadge;
  final VoidCallback onTap;

  const _PaperSwatch({
    required this.paper,
    required this.selected,
    required this.onTap,
    this.label,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = paper.background;
    final foreground = paper.foreground;

    return Semantics(
      button: true,
      selected: selected,
      label: label ?? paper.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: background ?? scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: paper.followsTheme
                  // 跟随主题这一档没有固定颜色可展示，用图标表意。
                  ? Icon(Icons.brightness_auto,
                      size: 22, color: scheme.onSurfaceVariant)
                  : Text(
                      showEditBadge ? '自' : '文',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 56,
              child: Text(
                label ?? paper.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义底色。只让用户调底色，字色由 [ReaderPaper.foregroundFor] 推——
/// 两个颜色都放开的话，深灰底配深灰字这种读不了的组合迟早会出现。
class _PaperColorDialog extends StatefulWidget {
  final Color initial;

  const _PaperColorDialog({required this.initial});

  @override
  State<_PaperColorDialog> createState() => _PaperColorDialogState();
}

class _PaperColorDialogState extends State<_PaperColorDialog> {
  late HSLColor _color = HSLColor.fromColor(widget.initial);

  Color get _background => _color.toColor();
  Color get _foreground => ReaderPaper.foregroundFor(_background);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义纸张'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                '芸香草能防蠹，古人拿它护书。',
                style: TextStyle(color: _foreground, fontSize: 16, height: 1.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '字色按对比度自动配，不用单独选。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _slider('色相', _color.hue, 0, 360,
                (v) => setState(() => _color = _color.withHue(v))),
            _slider('饱和度', _color.saturation, 0, 1,
                (v) => setState(() => _color = _color.withSaturation(v))),
            _slider('明度', _color.lightness, 0, 1,
                (v) => setState(() => _color = _color.withLightness(v))),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _background),
          child: const Text('使用'),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
