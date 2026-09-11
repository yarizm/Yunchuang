import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 覆盖应用数据目录的环境变量名。
const appDataDirectoryEnv = 'YUNCHUANG_DATA_DIR';

/// 应用数据目录：数据库、书籍文件、封面、词典、背景图都放在这里。
///
/// 默认是系统的文档目录。设了 [appDataDirectoryEnv] 就用它——截图、试新
/// 版本、排查问题时需要一个不碰真实书库的干净环境，改注册表或挪走用户
/// 的库都不是办法。目录不存在会建出来。
///
/// [environment] 只供测试注入，生产路径读 [Platform.environment]。
Future<Directory> appDataDirectory({Map<String, String>? environment}) {
  final override = (environment ?? Platform.environment)[appDataDirectoryEnv];
  if (override != null && override.trim().isNotEmpty) {
    return Directory(override.trim()).create(recursive: true);
  }
  return getApplicationDocumentsDirectory();
}
