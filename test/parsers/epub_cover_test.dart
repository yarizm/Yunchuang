import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yunchuang/parsers/epub_parser.dart';

// 1x1 的 PNG，内容本身无所谓，只要能认出是哪张图。
final _coverPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
final _otherPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// 拼一个最小的 EPUB：一张插图排在封面前面，用来证明取的不是「第一张图」。
Future<File> _writeEpub(
  Directory dir, {
  required String manifestExtra,
  required String metaExtra,
  String version = '3.0',
  String coverFileName = 'front.png',
}) async {
  final opf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="$version" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:test</dc:identifier>
    <dc:title>Cover Test</dc:title>
    <dc:language>en</dc:language>
    $metaExtra
  </metadata>
  <manifest>
    <item href="images/illustration.png" id="illustration" media-type="image/png"/>
    $manifestExtra
    <item href="chapter1.xhtml" id="chapter1" media-type="application/xhtml+xml"/>
    <item href="nav.xhtml" id="nav" media-type="application/xhtml+xml" properties="nav"/>
    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>''';
  const container = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>''';
  const ncx = '''<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="urn:uuid:test"/></head>
  <docTitle><text>Cover Test</text></docTitle>
  <navMap><navPoint id="n1" playOrder="1"><navLabel><text>One</text></navLabel><content src="chapter1.xhtml"/></navPoint></navMap>
</ncx>''';
  const chapter =
      '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>hello</p></body></html>';
  const nav = '<html xmlns="http://www.w3.org/1999/xhtml" '
      'xmlns:epub="http://www.idpf.org/2007/ops"><head><title>nav</title></head><body>'
      '<nav epub:type="toc"><ol><li><a href="chapter1.xhtml">One</a></li></ol></nav>'
      '</body></html>';

  final archive = Archive()
    ..addFile(ArchiveFile('mimetype', 20, utf8.encode('application/epub+zip')))
    ..addFile(ArchiveFile('META-INF/container.xml', container.length,
        utf8.encode(container)))
    ..addFile(ArchiveFile('OEBPS/content.opf', opf.length, utf8.encode(opf)))
    ..addFile(ArchiveFile('OEBPS/toc.ncx', ncx.length, utf8.encode(ncx)))
    ..addFile(ArchiveFile(
        'OEBPS/chapter1.xhtml', chapter.length, utf8.encode(chapter)))
    ..addFile(ArchiveFile('OEBPS/nav.xhtml', nav.length, utf8.encode(nav)))
    ..addFile(ArchiveFile(
        'OEBPS/images/illustration.png', _otherPng.length, _otherPng))
    ..addFile(ArchiveFile(
        'OEBPS/images/$coverFileName', _coverPng.length, _coverPng));
  final file = File('${dir.path}/book.epub');
  await file.writeAsBytes(ZipEncoder().encode(archive)!, flush: true);
  return file;
}

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('epub_cover');
  });
  tearDown(() => temp.delete(recursive: true));

  test('EPUB3：按 properties="cover-image" 找封面，而不是第一张图', () async {
    final file = await _writeEpub(
      temp,
      manifestExtra:
          '<item href="images/front.png" id="front" media-type="image/png" properties="cover-image"/>',
      metaExtra: '',
    );
    final epub = await EpubReader.readBook(await file.readAsBytes());

    expect(EpubParser.findCoverBytes(epub), _coverPng);
  });

  test('EPUB2：按 <meta name="cover"> 指向的 manifest 项找封面', () async {
    final file = await _writeEpub(
      temp,
      version: '2.0',
      manifestExtra:
          '<item href="images/front.png" id="front" media-type="image/png"/>',
      metaExtra: '<meta name="cover" content="front"/>',
    );
    final epub = await EpubReader.readBook(await file.readAsBytes());

    expect(EpubParser.findCoverBytes(epub), _coverPng);
  });

  test('什么都没声明时退到文件名带 cover 的图，没有就返回 null', () async {
    final plain = await _writeEpub(
      temp,
      manifestExtra:
          '<item href="images/front.png" id="front" media-type="image/png"/>',
      metaExtra: '',
    );
    final epub = await EpubReader.readBook(await plain.readAsBytes());
    expect(EpubParser.findCoverBytes(epub), isNull);

    final named = await _writeEpub(
      temp,
      coverFileName: 'cover.png',
      manifestExtra:
          '<item href="images/cover.png" id="front" media-type="image/png"/>',
      metaExtra: '',
    );
    final epub2 = await EpubReader.readBook(await named.readAsBytes());
    expect(EpubParser.findCoverBytes(epub2), _coverPng);
  });
}
