import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/reading_background.dart';

/// 应用全局背景。
///
/// 必须挂在 `MaterialApp` 的 `builder` 里，不能包在 `MaterialApp` 外面：包在
/// 外面就取不到 `Theme.of(context)`，颜色只能写死，三套主题下长得一模一样。
/// 之前正是那样——深棕底 + 粉蓝渐变 + 水彩插画常驻，日间主题于是变成「暖白
/// 顶栏压在深棕插画上」，书架的书籍网格区没有任何底色，插画整片露出来。
///
/// 现在底色一律取当前配色方案的 `surface`，装饰层只是叠加。
class AppBackground extends StatefulWidget {
  final Widget child;
  final AppBackgroundStyle style;

  /// [AppBackgroundStyle.custom] 用的图片绝对路径。文件不在就退回纯色。
  final String? customImagePath;

  /// 装饰层的浓度。0 等于纯色。
  final double intensity;

  /// 渐变的流动动画。阅读时会被关掉——正文旁边有东西在动很分神，也费电。
  final bool animationEnabled;

  const AppBackground({
    super.key,
    required this.child,
    this.style = AppBackgroundStyle.solid,
    this.customImagePath,
    this.intensity = 0.25,
    this.animationEnabled = true,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  /// [AppBackground.customImagePath] 指的文件在不在。
  ///
  /// 缓存而不是每次 build 都 `existsSync()`：这个部件挂在 `MaterialApp.builder`
  /// 里，每次路由切换、主题变化都会重建，每帧一次同步 stat 是主线程上的
  /// 无谓开销。正常情况下 `customBackgroundPathProvider` 已经确认过文件存在，
  /// 这里只是部件自己的兜底。
  bool _customImageExists = false;

  bool get _wantsAnimation =>
      widget.animationEnabled && widget.style == AppBackgroundStyle.gradient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (_wantsAnimation) _controller.repeat(reverse: true);
    _syncCustomImage();
  }

  @override
  void didUpdateWidget(AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
    if (oldWidget.customImagePath != widget.customImagePath) {
      _syncCustomImage();
    }
  }

  void _syncCustomImage() {
    final path = widget.customImagePath;
    _customImageExists = path != null && File(path).existsSync();
  }

  void _syncAnimation() {
    if (_wantsAnimation) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAnimation();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = widget.intensity.clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // 底色永远是当前主题的 surface。装饰层再浓也压在它上面，所以切主题
          // 时整屏的冷暖是跟着走的。
          Positioned.fill(child: ColoredBox(color: scheme.surface)),
          if (intensity > 0) ..._decoration(scheme, intensity),
          widget.child,
        ],
      ),
    );
  }

  List<Widget> _decoration(ColorScheme scheme, double intensity) {
    switch (widget.style) {
      case AppBackgroundStyle.solid:
        return const [];
      case AppBackgroundStyle.gradient:
        return [_gradients(scheme, intensity)];
      case AppBackgroundStyle.illustration:
        return [
          _imageLayer(
            const AssetImage('assets/home_bg.png'),
            intensity,
          ),
        ];
      case AppBackgroundStyle.custom:
        final path = widget.customImagePath;
        if (path == null || !_customImageExists) return const [];
        return [_imageLayer(FileImage(File(path)), intensity)];
    }
  }

  Widget _imageLayer(ImageProvider provider, double intensity) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          // 用 Image 自带的 opacity，不套 Opacity 部件：后者会为整屏开一层
          // 离屏缓冲（saveLayer），而这层背景在每一屏后面都在。
          opacity: AlwaysStoppedAnimation<double>(intensity),
          filterQuality: FilterQuality.medium,
          // 不设 cacheWidth。BoxFit.cover 在竖屏上是按长边铺满的，按屏幕
          // 尺寸算出来的宽度往往大于原图（内置插画只有 1024²），cacheWidth
          // 会把它**放大**解码，比不设还费内存。解码尺寸由导入时的 2160px
          // 上限控住，见 BackgroundImageService.maxEdge。
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// 三层缓慢移动的径向渐变，颜色由主题的强调色推出。
  ///
  /// 此前是写死的粉 / 蓝 / 紫，跟木色调的应用主题没有任何关系。
  Widget _gradients(ColorScheme scheme, double intensity) {
    final tints = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.primaryContainer,
    ];
    return Positioned.fill(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final val = _controller.value;
            return Stack(
              children: [
                _blob(
                  tints[0],
                  intensity,
                  Alignment(-0.8 + val * 0.4, -0.6 + val * 0.2),
                  1.5,
                ),
                _blob(
                  tints[1],
                  intensity,
                  Alignment(0.8 - val * 0.3, -0.8 + val * 0.5),
                  1.2,
                ),
                _blob(
                  tints[2],
                  intensity,
                  Alignment(sin(val * pi) * 0.4, 0.6 - val * 0.3),
                  1.4,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _blob(
    Color color,
    double intensity,
    Alignment center,
    double radius,
  ) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [
              color.withValues(alpha: 0.5 * intensity),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.6],
          ),
        ),
      ),
    );
  }
}
