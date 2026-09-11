import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 备份已经验证、放到 pending 目录之后弹的确认。
///
/// 恢复要等下次启动才真正落地，这段空档是个坑：SnackBar 四秒就没了，
/// 用户看书架没变以为没导进去，继续写笔记、改进度——重启后这些全被备份
/// 覆盖。所以用对话框把话说清楚，并给一个「立即退出」直接走到重启这一步。
Future<void> showRestoreStagedDialog(
  BuildContext context, {
  Future<void> Function() exitApp = _exitApp,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('备份已就绪'),
      content: const Text(
        '重新打开应用后完成恢复。\n\n'
        '在那之前对书籍、笔记和阅读进度的任何改动都会被备份覆盖，'
        '建议现在就退出。',
      ),
      actions: [
        TextButton(
          key: const Key('restore-staged-later'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('稍后'),
        ),
        FilledButton(
          key: const Key('restore-staged-exit'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await exitApp();
          },
          child: const Text('立即退出'),
        ),
      ],
    ),
  );
}

/// Android 走 SystemNavigator：结束 Activity 而不是杀进程，下次点图标会
/// 重新跑 main()，pending 的恢复就在那时应用。桌面端没有这一套，直接退。
Future<void> _exitApp() async {
  if (Platform.isAndroid) {
    await SystemNavigator.pop();
    return;
  }
  exit(0);
}
