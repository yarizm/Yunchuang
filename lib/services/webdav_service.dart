import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

/// WebDAV 服务器配置。
///
/// 密码存在 SharedPreferences 里而不是数据库：备份 ZIP 只打包数据库、书籍
/// 与封面（见 [BackupService]），不含 SharedPreferences，所以密码不会跟着
/// 分享出去的备份走。若将来把它挪进数据库，必须同步加进
/// `BackupService._redactCredentials`。
class WebDavConfig {
  final String baseUrl;
  final String username;
  final String password;

  /// 备份存放的远端目录名，相对 [baseUrl]。
  final String remoteDir;

  const WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.remoteDir = 'yunchuang',
  });

  bool get isComplete =>
      baseUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  /// 目录的绝对 URL，末尾带斜杠——WebDAV 服务器普遍靠末尾斜杠区分集合与资源。
  String get directoryUrl {
    final base = baseUrl.trim();
    final root = base.endsWith('/') ? base : '$base/';
    final dir = remoteDir.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return dir.isEmpty ? root : '$root$dir/';
  }

  String fileUrl(String name) => '$directoryUrl${Uri.encodeComponent(name)}';

  WebDavConfig copyWith({
    String? baseUrl,
    String? username,
    String? password,
    String? remoteDir,
  }) {
    return WebDavConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDir: remoteDir ?? this.remoteDir,
    );
  }
}

/// 远端的一个备份文件。
class WebDavEntry {
  final String name;
  final int size;
  final DateTime? modifiedAt;

  const WebDavEntry({
    required this.name,
    required this.size,
    this.modifiedAt,
  });
}

class WebDavException implements Exception {
  final String message;

  /// 原始 HTTP 状态码，没有对应状态时为 null。
  /// 调用方按它判断（例如目录不存在），不要去匹配 [message] 文本。
  final int? statusCode;

  const WebDavException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// 用 Dio 直接说 WebDAV，不引第三方客户端。
///
/// 这里只用到四个动词：PROPFIND 列目录、MKCOL 建目录、PUT 上传、GET 下载。
/// 为这点用量引入一个额外的包（且社区常用的那个需要 fork 才能用）不划算，
/// dio 和 xml 都已经在依赖里。
class WebDavService {
  final Dio _dio;

  WebDavService(this._dio);

  /// 只列目录，不改动任何东西——用来验证地址与账号密码是否正确。
  Future<void> testConnection(WebDavConfig config) async {
    if (!config.isComplete) {
      throw const WebDavException('请先填写服务器地址与用户名');
    }
    await _propfind(config, config.baseUrl);
  }

  /// 建备份目录。已存在时服务器返回 405，视为成功。
  Future<void> ensureRemoteDir(WebDavConfig config) async {
    try {
      await _dio.requestUri<void>(
        Uri.parse(config.directoryUrl),
        options: _options(config, 'MKCOL'),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // 405 Method Not Allowed = 目录已存在；301/302 一般也是同一个意思。
      if (status == 405 || status == 301 || status == 302) return;
      throw _translate(error, '创建远端目录失败');
    }
  }

  Future<WebDavEntry> uploadBackup(
    WebDavConfig config,
    String localPath,
  ) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw WebDavException('本地备份文件不存在：$localPath');
    }
    await ensureRemoteDir(config);

    final name = localPath.split(RegExp(r'[/\\]')).last;
    final bytes = await file.readAsBytes();
    try {
      await _dio.requestUri<void>(
        Uri.parse(config.fileUrl(name)),
        data: Stream.fromIterable([bytes]),
        options: _options(config, 'PUT', headers: {
          Headers.contentLengthHeader: bytes.length,
          Headers.contentTypeHeader: 'application/zip',
        }),
      );
    } on DioException catch (error) {
      throw _translate(error, '上传备份失败');
    }
    return WebDavEntry(
      name: name,
      size: bytes.length,
      modifiedAt: DateTime.now(),
    );
  }

  /// 列出远端目录里的备份，按修改时间倒序（新的在前）。
  ///
  /// 目录还不存在时返回空列表而不是报错——第一次用还没传过东西是正常的。
  Future<List<WebDavEntry>> listBackups(WebDavConfig config) async {
    final XmlDocument document;
    try {
      document = await _propfind(config, config.directoryUrl);
    } on WebDavException catch (error) {
      if (error.statusCode == 404) return const [];
      rethrow;
    }

    final entries = <WebDavEntry>[];
    for (final response in _childrenNamed(document.rootElement, 'response')) {
      final href = _firstText(response, 'href');
      if (href == null) continue;
      final name = _nameFromHref(href);
      // 目录自身也在结果里（Depth: 1 包含集合本身），且只关心备份包。
      if (name.isEmpty || !name.toLowerCase().endsWith('.zip')) continue;

      entries.add(WebDavEntry(
        name: name,
        size: int.tryParse(_firstText(response, 'getcontentlength') ?? '') ?? 0,
        modifiedAt: _parseHttpDate(_firstText(response, 'getlastmodified')),
      ));
    }

    entries.sort((a, b) {
      final left = a.modifiedAt;
      final right = b.modifiedAt;
      if (left == null && right == null) return b.name.compareTo(a.name);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return entries;
  }

  /// 下载 [name] 到 [targetPath]，返回本地路径。
  Future<String> downloadBackup(
    WebDavConfig config,
    String name,
    String targetPath,
  ) async {
    try {
      final response = await _dio.requestUri<List<int>>(
        Uri.parse(config.fileUrl(name)),
        options: _options(config, 'GET', responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const WebDavException('远端备份内容为空');
      }
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return targetPath;
    } on DioException catch (error) {
      throw _translate(error, '下载备份失败');
    }
  }

  Future<XmlDocument> _propfind(WebDavConfig config, String url) async {
    try {
      final response = await _dio.requestUri<String>(
        Uri.parse(url),
        // Depth: 1 只列一层，不递归整个网盘。
        data: '<?xml version="1.0" encoding="utf-8"?>'
            '<d:propfind xmlns:d="DAV:"><d:allprop/></d:propfind>',
        options: _options(
          config,
          'PROPFIND',
          responseType: ResponseType.plain,
          headers: {
            'Depth': '1',
            Headers.contentTypeHeader: 'application/xml',
          },
        ),
      );
      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const WebDavException('服务器返回空响应，地址可能不是 WebDAV 入口');
      }
      final XmlDocument document;
      try {
        document = XmlDocument.parse(body);
      } on XmlException {
        throw const WebDavException('服务器返回的不是 WebDAV 响应，请检查地址');
      }
      // HTML 登录页也是合法 XML，解析成功不等于对方是 WebDAV。不校验的话
      // 地址填成网盘的网页入口会「成功」返回 0 个备份，用户以为备份丢了。
      if (document.rootElement.name.local != 'multistatus') {
        throw const WebDavException('服务器返回的不是 WebDAV 响应，请检查地址');
      }
      return document;
    } on DioException catch (error) {
      throw _translate(error, '连接失败');
    }
  }

  Options _options(
    WebDavConfig config,
    String method, {
    Map<String, dynamic> headers = const {},
    ResponseType? responseType,
  }) {
    final credentials =
        base64Encode(utf8.encode('${config.username}:${config.password}'));
    return Options(
      method: method,
      responseType: responseType,
      headers: {
        'Authorization': 'Basic $credentials',
        ...headers,
      },
      // 4xx/5xx 交给下面的 _translate 翻译成中文，不要 Dio 的默认报错。
      validateStatus: (status) => status != null && status < 400,
    );
  }

  WebDavException _translate(DioException error, String prefix) {
    final status = error.response?.statusCode;
    return switch (status) {
      401 || 403 => WebDavException('认证失败，请检查用户名与密码', statusCode: status),
      404 => WebDavException('$prefix：路径不存在（404）', statusCode: 404),
      507 => const WebDavException('远端空间不足', statusCode: 507),
      _
          when error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout =>
        const WebDavException('连接超时，请检查网络与服务器地址'),
      _ when error.type == DioExceptionType.connectionError =>
        const WebDavException('无法连接到服务器，请检查地址与网络'),
      null => WebDavException('$prefix：${error.message ?? error.type.name}'),
      _ => WebDavException('$prefix：HTTP $status', statusCode: status),
    };
  }
}

/// PROPFIND 的响应命名空间前缀各家不一（`d:` `D:` `lp1:` 甚至没有），
/// 所以按 local name 找，不按带前缀的全名。
Iterable<XmlElement> _childrenNamed(XmlElement root, String localName) {
  return root.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == localName);
}

String? _firstText(XmlElement scope, String localName) {
  for (final element in scope.descendants.whereType<XmlElement>()) {
    if (element.name.local == localName) {
      final text = element.innerText.trim();
      if (text.isNotEmpty) return text;
    }
  }
  return null;
}

String _nameFromHref(String href) {
  final trimmed = href.trim().replaceAll(RegExp(r'/+$'), '');
  final last = trimmed.split('/').last;
  return Uri.decodeComponent(last);
}

/// getlastmodified 是 RFC 1123 格式（Fri, 05 Sep 2026 03:30:00 GMT），
/// DateTime.parse 不认，这里手动解析；解析不出来就返回 null，列表照样能显示。
DateTime? _parseHttpDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return HttpDate.parse(raw);
  } catch (_) {
    return DateTime.tryParse(raw);
  }
}
