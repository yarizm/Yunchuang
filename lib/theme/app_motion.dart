import 'package:flutter/widgets.dart';

/// 界面动画开关（设置 → 外观 → 界面动画）。
///
/// 挂在 `MaterialApp.builder` 里，所有路由、弹层都在它下面。找不到这一层
/// （单独测某个部件）按关闭算，部件保持关掉时的样子；系统开了「移除动画」
/// （`MediaQuery.disableAnimations`）也按关闭算。
///
/// **开关只改参数，不改部件树的形状。** 按开关返回不同结构的部件（开着包一层
/// 变换、关着直接返回 child），用户一拨开关，下面整棵子树就会被卸载重建：
/// 页面状态丢失、封面重新解码。所以各处开关两边都是同一套部件，关着时时长为 0、
/// 变换为单位矩阵。页面转场在推入时就定下来，见 `GlassPageRoute`。
class AppMotion extends InheritedWidget {
  const AppMotion({super.key, required this.enabled, required super.child});

  /// 用户的设置。实际生不生效还要看系统的「移除动画」，见 [of]。
  final bool enabled;

  /// 推入普通页面：从下方升上来淡入。
  static const pageEnter = Duration(milliseconds: 380);

  /// 打开书：从书封所在的卡片张开到全屏。
  static const bookOpen = Duration(milliseconds: 460);

  /// 退出页面。
  static const pageExit = Duration(milliseconds: 300);

  /// 底部 Tab 之间切换。
  static const tabSwitch = Duration(milliseconds: 300);

  /// 翻页模式换章。
  static const chapterSwitch = Duration(milliseconds: 380);

  /// 卡片按下、松手回弹。
  static const press = Duration(milliseconds: 100);
  static const release = Duration(milliseconds: 280);

  /// 界面动画开着没有。build 里用：开关一变，调用方跟着重建。
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppMotion>();
    if (scope == null || !scope.enabled) return false;
    return !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  /// 同 [of]，但不登记依赖，给 build 之外的地方用（路由推入时定转场）。
  static bool peek(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppMotion>();
    if (scope == null || !scope.enabled) return false;
    final media = context.getInheritedWidgetOfExactType<MediaQuery>();
    return !(media?.data.disableAnimations ?? false);
  }

  @override
  bool updateShouldNotify(AppMotion oldWidget) => enabled != oldWidget.enabled;
}
