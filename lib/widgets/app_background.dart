import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading_background.dart';
import '../providers/preferences_provider.dart';
import '../providers/ui_provider.dart';

/// 应用全局背景。
///
/// 必须挂在 `MaterialApp` 里面，不能包在外面：包在外面就取不到
/// `Theme.of(context)`，颜色只能写死，三套主题下长得一模一样。之前正是那样
/// ——深棕底 + 粉蓝渐变 + 水彩插画常驻，日间主题于是变成「暖白顶栏压在深棕
/// 插画上」，书架的书籍网格区没有任何底色，插画整片露出来。
///
/// 现在底色一律取当前配色方案的 `surface`，装饰层只是叠加。
///
/// 它是**每个页面各画一层**，不是整个应用只画一层压在最底下：主 Tab 的
/// `MainShell` 一层，`GlassPageRoute` 推入的每个页面一层，阅读器在纸张主题
/// 里再来一层（底色于是就是纸张色）。页面自己的 `Scaffold` 是透明的——由
/// `AppTheme` 的 `scaffoldBackgroundColor` 统一给——所以背景在哪一页都看得见。
/// 只画一层的话，推入的页面要么透出下面那页的内容，要么像以前那样自己再
/// 铺一层 96% 不透明的 surface 把背景全盖掉，结果就是「背景只有书架有」。
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

/// 按用户偏好配置好的 [AppBackground]。页面级背景都从这里拿。
class PreferredAppBackground extends ConsumerWidget {
  final Widget child;

  /// 阅读器传 false：正文旁边有东西在动很分神，也费电。
  final bool animationEnabled;

  const PreferredAppBackground({
    super.key,
    required this.child,
    this.animationEnabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(
      style: ref.watch(effectiveBackgroundStyleProvider),
      customImagePath: ref.watch(customBackgroundPathProvider),
      intensity: ref.watch(
        preferencesProvider.select((p) => p.backgroundIntensity),
      ),
      animationEnabled: animationEnabled,
      child: child,
    );
  }
}

class _AppBackgroundState extends State<AppBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  /// 图片层的不透明度。
  ///
  /// 是一个可变的 Animation 而不是每次 build 新建 `AlwaysStoppedAnimation`：
  /// `RenderImage` 换 opacity 对象时只换监听、**不会** markNeedsPaint，而这层
  /// 又在自己的 RepaintBoundary 里，没有别的东西会带着它重画——结果就是
  /// 设置页拖浓度滑块，背景一动不动。改这个对象的 value 会通知监听者重画。
  late final AnimationController _imageOpacity;

  /// [AppBackground.customImagePath] 指的文件在不在。
  ///
  /// 缓存而不是每次 build 都 `existsSync()`：这个部件每次路由切换、主题变化
  /// 都会重建，每帧一次同步 stat 是主线程上的无谓开销。正常情况下
  /// `customBackgroundPathProvider` 已经确认过文件存在，这里只是部件自己的
  /// 兜底。
  bool _customImageExists = false;

  bool get _wantsAnimation =>
      widget.animationEnabled && widget.style == AppBackgroundStyle.gradient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this, duration: _gradientPeriod);
    _imageOpacity = AnimationController(
      vsync: this,
      value: widget.intensity.clamp(0.0, 1.0),
    );
    if (_wantsAnimation) _controller.repeat(reverse: true);
    _syncCustomImage();
  }

  @override
  void didUpdateWidget(AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
    _imageOpacity.value = widget.intensity.clamp(0.0, 1.0);
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
    _imageOpacity.dispose();
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
        return [_imageLayer(const AssetImage('assets/home_bg.png'))];
      case AppBackgroundStyle.custom:
        final path = widget.customImagePath;
        if (path == null || !_customImageExists) return const [];
        return [_imageLayer(FileImage(File(path)))];
    }
  }

  Widget _imageLayer(ImageProvider provider) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          // 用 Image 自带的 opacity，不套 Opacity 部件：后者会为整屏开一层
          // 离屏缓冲（saveLayer），而这层背景在每一屏后面都在。
          opacity: _imageOpacity,
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
            final val = _gradientPhase();
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

const _gradientPeriod = Duration(seconds: 20);

/// 进程启动时刻。渐变的位置从它算，见 [_gradientPhase]。
final _gradientEpoch = DateTime.now();

/// 渐变走到哪了：0 → 1 → 0 来回，一个来回是 [_gradientPeriod] 的两倍。
///
/// 按挂钟算而不是读 `_controller.value`：每个页面各有一个 [AppBackground]，
/// 各自的控制器从挂载那一刻起跳，两页之间淡入淡出时渐变就会瞬移一下。
/// 挂钟是所有实例共用的，两边的位置永远一致。控制器只负责每帧触发重建。
double _gradientPhase() {
  final elapsed = DateTime.now().difference(_gradientEpoch).inMilliseconds /
      _gradientPeriod.inMilliseconds;
  final cycle = elapsed % 2;
  return cycle <= 1 ? cycle : 2 - cycle;
}
