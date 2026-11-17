import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/home/home_page.dart';
import 'pages/notes/notes_page.dart';
import 'pages/stats/reading_stats_page.dart';
import 'pages/settings/settings_page.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';
import 'utils/app_orientation.dart';
import 'providers/database_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/webdav_provider.dart';
import 'widgets/animated_branch_container.dart';
import 'widgets/app_background.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        // 默认的 IndexedStack 切 Tab 是硬切，换成能淡入淡出的容器。
        navigatorContainerBuilder: (context, navigationShell, children) =>
            AnimatedBranchContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: HomePage())),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/notes',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: NotesPage())),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/stats',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: ReadingStatsPage())),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/settings',
                  pageBuilder: (context, state) =>
                      const NoTransitionPage(child: SettingsPage())),
            ],
          ),
        ],
      ),
    ],
  );
});

class ReadingOfflineApp extends ConsumerWidget {
  const ReadingOfflineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeStr = ref.watch(preferencesProvider.select((p) => p.theme));
    final enhancedAnimations =
        ref.watch(preferencesProvider.select((p) => p.enhancedAnimations));

    // 全局背景不在这里：它是每个页面各画一层的（MainShell 一层、每个
    // GlassPageRoute 一层），见 AppBackground 的说明。
    return MaterialApp.router(
      title: '芸窗',
      theme: AppTheme.resolve(themeStr, Brightness.light),
      darkTheme: AppTheme.resolve(themeStr, Brightness.dark),
      routerConfig: router,
      // 挂在这里，所有路由和弹层都在它下面，见 AppMotion。
      builder: (context, child) => AppMotion(
        enabled: enhancedAnimations,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    _applyOrientation(ref.read(preferencesProvider).preferredOrientation);
    // 用量计数器要在第一次 AI 请求之前接到 AIService 上，见它的注释。
    ref.read(aiUsageTrackerProvider);
    _maybeAutoBackup();
  }

  /// 到期就跑一次自动备份。
  ///
  /// 放在启动而不是退到后台：后台进程随时可能被系统回收，导出（VACUUM
  /// 整个数据库再拷贝全部书籍）跑到一半被杀既留下垃圾也没有备份。
  ///
  /// 不 await、不弹提示：这是后台动作，网盘连不上不该拦着用户读书。
  /// 结果记在偏好里，设置页的 WebDAV 那一栏能看到上次备份时间。
  void _maybeAutoBackup() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final config = ref.read(webDavConfigProvider);
      await ref.read(autoBackupServiceProvider).runIfDue(config);
    });
  }

  void _applyOrientation(String orientation) {
    applyAppOrientation(orientation);
  }

  @override
  Widget build(BuildContext context) {
    // 偏好变化时重新 apply 方向
    ref.listen(preferencesProvider.select((p) => p.preferredOrientation),
        (_, next) => _applyOrientation(next));

    // 背景放在 MaterialApp 里面而不是包在外面：只有在里面才拿得到
    // Theme.of(context)，底色才能跟着主题走。四个 Tab 的 Scaffold 都是透明的，
    // 这一层就是它们的底。
    return PreferredAppBackground(
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (i) {
            widget.navigationShell.goBranch(
              i,
              initialLocation: i == widget.navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.book),
              selectedIcon: _SelectedNavIcon(Icons.book),
              label: '书架',
            ),
            NavigationDestination(
              icon: Icon(Icons.note),
              selectedIcon: _SelectedNavIcon(Icons.note),
              label: '笔记',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart),
              selectedIcon: _SelectedNavIcon(Icons.bar_chart),
              label: '统计',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              selectedIcon: _SelectedNavIcon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}

/// 底栏选中的图标：选中那一下轻轻弹一下（界面动画开着时）。
///
/// NavigationBar 在选中和未选中之间换的是两个不同的部件，选中时这个部件
/// 新挂上去，动画就从头播一次；之后重建不会再播。
class _SelectedNavIcon extends StatelessWidget {
  final IconData icon;

  const _SelectedNavIcon(this.icon);

  static final _bounce = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.8, end: 1.14)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.14, end: 1)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // begin 只在第一次 build 时用到：动画关着时起点就是终点，不播。
      tween: Tween(begin: AppMotion.of(context) ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 360),
      builder: (context, t, child) =>
          Transform.scale(scale: _bounce.transform(t), child: child),
      child: Icon(icon),
    );
  }
}
