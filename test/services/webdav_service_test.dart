import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yunchuang/services/webdav_service.dart';

class MockDio extends Mock implements Dio {}

const _config = WebDavConfig(
  baseUrl: 'https://dav.example.com/dav',
  username: 'reader',
  password: 'secret',
);

/// 常见 WebDAV 服务器的 PROPFIND 响应，带 `d:` 命名空间前缀。
const _propfindBody = '''
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/yunchuang/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/yunchuang/backup_2026-09-01.zip</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>120</d:getcontentlength>
      <d:getlastmodified>Tue, 01 Sep 2026 10:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/yunchuang/backup_2026-09-04.zip</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>340</d:getcontentlength>
      <d:getlastmodified>Fri, 04 Sep 2026 10:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/yunchuang/readme.txt</d:href>
    <d:propstat><d:prop><d:getcontentlength>5</d:getcontentlength></d:prop></d:propstat>
  </d:response>
</d:multistatus>
''';

Response<T> _ok<T>(T data, {int status = 207}) => Response<T>(
      data: data,
      statusCode: status,
      requestOptions: RequestOptions(path: ''),
    );

DioException _httpError(int status) => DioException(
      requestOptions: RequestOptions(path: ''),
      response: Response(
        statusCode: status,
        requestOptions: RequestOptions(path: ''),
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  late MockDio dio;
  late WebDavService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    service = WebDavService(dio);
  });

  group('WebDavConfig', () {
    test('目录 URL 末尾补斜杠，去掉多余的斜杠', () {
      const a = WebDavConfig(
        baseUrl: 'https://x.com/dav',
        username: 'u',
        password: 'p',
        remoteDir: 'books',
      );
      const b = WebDavConfig(
        baseUrl: 'https://x.com/dav/',
        username: 'u',
        password: 'p',
        remoteDir: '/books/',
      );

      expect(a.directoryUrl, 'https://x.com/dav/books/');
      expect(b.directoryUrl, 'https://x.com/dav/books/');
    });

    test('目录名为空时直接用根路径', () {
      const config = WebDavConfig(
        baseUrl: 'https://x.com/dav',
        username: 'u',
        password: 'p',
        remoteDir: '',
      );

      expect(config.directoryUrl, 'https://x.com/dav/');
    });

    test('文件名做 URL 编码，含空格与中文的备份名不会拼坏', () {
      const config = WebDavConfig(
        baseUrl: 'https://x.com/dav',
        username: 'u',
        password: 'p',
        remoteDir: 'd',
      );

      expect(config.fileUrl('备份 1.zip'), contains('%20'));
      expect(config.fileUrl('备份 1.zip'), startsWith('https://x.com/dav/d/'));
    });

    test('地址或用户名为空视为未配置完成', () {
      expect(
        const WebDavConfig(baseUrl: '', username: 'u', password: 'p')
            .isComplete,
        isFalse,
      );
      expect(
        const WebDavConfig(baseUrl: 'https://x', username: ' ', password: 'p')
            .isComplete,
        isFalse,
      );
    });
  });

  group('listBackups', () {
    test('只返回 zip，跳过目录自身与其他文件', () async {
      when(() => dio.requestUri<String>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok(_propfindBody));

      final entries = await service.listBackups(_config);

      expect(entries.map((e) => e.name), [
        'backup_2026-09-04.zip',
        'backup_2026-09-01.zip',
      ]);
    });

    test('按修改时间倒序，新的在前', () async {
      when(() => dio.requestUri<String>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok(_propfindBody));

      final entries = await service.listBackups(_config);

      expect(entries.first.name, 'backup_2026-09-04.zip');
      expect(entries.first.size, 340);
      expect(entries.first.modifiedAt, isNotNull);
    });

    // 第一次用还没上传过任何东西，目录不存在是正常的，不该弹错误。
    test('目录不存在时返回空列表而不是抛异常', () async {
      when(() => dio.requestUri<String>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenThrow(_httpError(404));

      expect(await service.listBackups(_config), isEmpty);
    });

    test('命名空间前缀不同也能解析', () async {
      const upperCasePrefix = '''
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/dav/yunchuang/a.zip</D:href>
    <D:propstat><D:prop><D:getcontentlength>9</D:getcontentlength></D:prop></D:propstat>
  </D:response>
</D:multistatus>
''';
      when(() => dio.requestUri<String>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok(upperCasePrefix));

      final entries = await service.listBackups(_config);

      expect(entries.single.name, 'a.zip');
      expect(entries.single.size, 9);
    });

    test('返回的不是 XML 时提示地址可能不对', () async {
      when(() => dio.requestUri<String>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok('<html>login page</html>'));

      await expectLater(
        service.listBackups(_config),
        throwsA(isA<WebDavException>()),
      );
    });
  });

  group('错误翻译', () {
    test('401 说认证失败，不暴露原始状态码', () async {
      when(() => dio.requestUri<String>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenThrow(_httpError(401));

      await expectLater(
        service.testConnection(_config),
        throwsA(
          isA<WebDavException>().having(
            (e) => e.message,
            'message',
            contains('认证失败'),
          ),
        ),
      );
    });

    test('连接超时给出可操作的提示', () async {
      when(() => dio.requestUri<String>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      await expectLater(
        service.testConnection(_config),
        throwsA(
          isA<WebDavException>()
              .having((e) => e.message, 'message', contains('超时')),
        ),
      );
    });

    test('未填地址时不发请求就报错', () async {
      const empty = WebDavConfig(baseUrl: '', username: '', password: '');

      await expectLater(
        service.testConnection(empty),
        throwsA(isA<WebDavException>()),
      );
      verifyNever(() => dio.requestUri<String>(any(),
          data: any(named: 'data'), options: any(named: 'options')));
    });
  });

  group('uploadBackup', () {
    test('本地文件不存在时直接报错，不发请求', () async {
      await expectLater(
        service.uploadBackup(_config, '/definitely/not/here.zip'),
        throwsA(isA<WebDavException>()),
      );
      verifyNever(() => dio.requestUri<void>(any(),
          data: any(named: 'data'), options: any(named: 'options')));
    });

    test('上传前建目录，目录已存在（405）不算失败', () async {
      final temp = await Directory.systemTemp.createTemp('webdav_upload');
      addTearDown(() => temp.deleteSync(recursive: true));
      final zip = File('${temp.path}/backup_test.zip')
        ..writeAsBytesSync(List.filled(64, 1));

      var mkcolCalls = 0;
      when(() => dio.requestUri<void>(any(),
          data: any(named: 'data'),
          options: any(named: 'options'))).thenAnswer((invocation) async {
        final options = invocation.namedArguments[#options] as Options;
        if (options.method == 'MKCOL') {
          mkcolCalls++;
          throw _httpError(405);
        }
        return _ok<void>(null, status: 201);
      });

      final entry = await service.uploadBackup(_config, zip.path);

      expect(mkcolCalls, 1);
      expect(entry.name, 'backup_test.zip');
      expect(entry.size, 64);
    });
  });

  group('downloadBackup', () {
    test('把字节写到目标路径', () async {
      final temp = await Directory.systemTemp.createTemp('webdav_download');
      addTearDown(() => temp.deleteSync(recursive: true));
      final target = '${temp.path}/nested/restored.zip';

      when(() =>
              dio.requestUri<List<int>>(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _ok<List<int>>([1, 2, 3], status: 200));

      final path = await service.downloadBackup(_config, 'a.zip', target);

      expect(path, target);
      expect(File(target).readAsBytesSync(), [1, 2, 3]);
    });

    test('远端返回空内容时报错而不是写出空文件', () async {
      final temp = await Directory.systemTemp.createTemp('webdav_empty');
      addTearDown(() => temp.deleteSync(recursive: true));
      final target = '${temp.path}/empty.zip';

      when(() =>
              dio.requestUri<List<int>>(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _ok<List<int>>(const [], status: 200));

      await expectLater(
        service.downloadBackup(_config, 'a.zip', target),
        throwsA(isA<WebDavException>()),
      );
      expect(File(target).existsSync(), isFalse);
    });
  });
}
