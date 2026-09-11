import 'package:flutter/material.dart';

import '../services/shared_import_service.dart';

/// 在启动时与每次回到前台时，取走待导入的分享文件并交给 [onFiles]。
///
/// 做成包裹型 widget 而不是塞进书架页：书架页是 StatelessWidget，而这里需要
/// 监听生命周期。与 `BookDropTarget` 同一个形状，两条导入路径共用书架页里
/// 那一套重复检测与元数据编辑流程。
class SharedImportWatcher extends StatefulWidget {
  final Widget child;
  final Future<void> Function(List<String> paths) onFiles;
  final SharedImportService? service;

  const SharedImportWatcher({
    super.key,
    required this.child,
    required this.onFiles,
    this.service,
  });

  @override
  State<SharedImportWatcher> createState() => _SharedImportWatcherState();
}

class _SharedImportWatcherState extends State<SharedImportWatcher>
    with WidgetsBindingObserver {
  late final SharedImportService _service =
      widget.service ?? SharedImportService();

  /// 导入过程里会弹重复确认框，期间应用会短暂失焦再恢复，不能因此重入。
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 冷启动就是被分享拉起来的情况，第一帧之后就去取。
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drain();
  }

  Future<void> _drain() async {
    if (_handling || !mounted) return;
    _handling = true;
    try {
      final paths = await _service.consumePending();
      if (paths.isEmpty || !mounted) return;
      try {
        await widget.onFiles(paths);
      } finally {
        // 导入成功与否都清缓存副本：书已经拷进应用存储，留着只是白占体积。
        await _service.discard(paths);
      }
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
