import 'dart:ui';
import 'package:flutter/material.dart';

Color stableSurfaceColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.colorScheme.surface.withValues(
    alpha: theme.brightness == Brightness.dark ? 0.94 : 0.96,
  );
}

/// 毛玻璃效果容器 (Glassmorphism)
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Border? border;
  final bool stable;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.blur = 20.0,
    this.color,
    this.border,
  }) : stable = false;

  const GlassContainer.stable({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.color,
    this.border,
  })  : blur = 0,
        stable = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultColor = stable
        ? stableSurfaceColor(context)
        : isDark
            ? const Color(0xFF2D2D2D).withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.65);

    final defaultBorder = border ??
        Border.all(
          color: stable
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.72)
              : isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
          width: 1.0,
        );

    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: defaultBorder,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: blur <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: decorated,
              ),
      ),
    );
  }
}

/// 鼠标悬浮微动效包装器 (Hover Float)
class HoverFloat extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HoverFloat({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<HoverFloat> createState() => _HoverFloatState();
}

class _HoverFloatState extends State<HoverFloat> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform:
              Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
