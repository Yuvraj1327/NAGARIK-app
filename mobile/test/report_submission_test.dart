import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/features/reports/data/reports_repository.dart';
import 'package:nagarik/features/reports/domain/report_draft.dart';

/// Covers the Report an Issue submission path end to end on the Dart side:
/// the multipart body that `ReportsRepository.submitReport` actually puts on
/// the wire, the client-side image checks, and how server errors surface.

const _jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01];
const _pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];
const _webpBytes = [0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50];
// A HEIC `ftyp` box — what an iPhone gallery pick can produce.
const _heicBytes = [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63];

String _jwt() {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'ES256', 'typ': 'JWT'})}.${b64({'exp': exp})}.sig';
}

class _FakeAuth implements GoTrueClient {
  final Session _session = Session(
    accessToken: _jwt(),
    tokenType: 'bearer',
    refreshToken: 'refresh',
    user: const User(
      id: 'user-1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );

  @override
  Session? get currentSession => _session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _createdReport = {
  'id': 'report-1',
  'reference_id': 'NGR-2026-00001',
  'user_id': 'user-1',
  'category': 'road',
  'description': 'Large pothole near the bus stop.',
  'city': 'Pune',
  'pin_code': '411001',
  'latitude': null,
  'longitude': null,
  'image_paths': <String>[],
  'image_urls': <String>[],
  'status': 'submitted',
  'created_at': '2026-01-15T10:30:00+00:00',
  'updated_at': '2026-01-15T10:30:00+00:00',
};

class _CapturingBackend implements HttpClientAdapter {
  _CapturingBackend({this.status = 201, this.body = _createdReport});

  final int status;
  final Map<String, Object?> body;
  RequestOptions? request;
  String requestBody = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    // latin1 keeps arbitrary binary bytes intact so the text parts can be
    // searched for without a decode error.
    requestBody = latin1.decode(bytes);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('nagarik_report_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  XFile photo(String name, List<int> bytes) {
    final file = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
    return XFile(file.path);
  }

  ({ReportsRepository repo, _CapturingBackend backend}) setup({
    int status = 201,
    Map<String, Object?> body = _createdReport,
  }) {
    final backend = _CapturingBackend(status: status, body: body);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = backend;
    return (
      repo: ReportsRepository(ApiClient(dio: dio, auth: _FakeAuth())),
      backend: backend,
    );
  }

  ReportDraft draft({List<XFile> images = const []}) => ReportDraft()
    ..category = ReportCategory.road
    ..description = '  Large pothole near the bus stop.  '
    ..city = ' Pune '
    ..pinCode = '411001'
    ..images = [...images];

  group('detectImageContentType', () {
    test('recognizes JPEG, PNG and WebP by their bytes', () {
      expect(ReportsRepository.detectImageContentType(_jpegBytes)?.mimeType, 'image/jpeg');
      expect(ReportsRepository.detectImageContentType(_pngBytes)?.mimeType, 'image/png');
      expect(ReportsRepository.detectImageContentType(_webpBytes)?.mimeType, 'image/webp');
    });

    test('rejects HEIC, empty and truncated input', () {
      expect(ReportsRepository.detectImageContentType(_heicBytes), isNull);
      expect(ReportsRepository.detectImageContentType(const []), isNull);
      expect(ReportsRepository.detectImageContentType(const [0xFF, 0xD8]), isNull);
      // "RIFF....WAVE" is RIFF but not WebP.
      expect(
        ReportsRepository.detectImageContentType(
            const [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45]),
        isNull,
      );
    });
  });

  group('submitReport', () {
    test('sends trimmed fields, the real content type, and a long timeout', () async {
      final t = setup();
      // No extension on purpose: Dio alone would label this
      // application/octet-stream and the backend would reject it.
      final d = draft(images: [photo('picked_from_gallery', _jpegBytes)])
        ..latitude = 18.5204
        ..longitude = 73.8567;

      final report = await t.repo.submitReport(d);

      expect(report.referenceId, 'NGR-2026-00001');
      final body = t.backend.requestBody;
      expect(body, contains('name="category"\r\n\r\nroad'));
      expect(body, contains('name="description"\r\n\r\nLarge pothole near the bus stop.\r\n'));
      expect(body, contains('name="city"\r\n\r\nPune\r\n'));
      expect(body, contains('name="pin_code"\r\n\r\n411001'));
      expect(body, contains('name="latitude"\r\n\r\n18.5204'));
      expect(body, contains('name="longitude"\r\n\r\n73.8567'));
      expect(body, contains('name="images"; filename="picked_from_gallery"'));
      expect(body, contains('content-type: image/jpeg'));
      expect(t.backend.request!.sendTimeout, const Duration(minutes: 2));
      expect(t.backend.request!.receiveTimeout, const Duration(minutes: 2));
    });

    test('omits coordinates when none were captured', () async {
      final t = setup();

      await t.repo.submitReport(draft());

      expect(t.backend.requestBody, isNot(contains('name="latitude"')));
      expect(t.backend.requestBody, isNot(contains('name="longitude"')));
    });

    test('never sends half a coordinate pair', () async {
      final t = setup();

      await t.repo.submitReport(draft()..latitude = 18.5);

      expect(t.backend.requestBody, isNot(contains('name="latitude"')));
    });

    test('rejects a HEIC photo locally without calling the server', () async {
      final t = setup();

      await expectLater(
        t.repo.submitReport(draft(images: [photo('IMG_0001.heic', _heicBytes)])),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('JPEG, PNG or WebP'))),
      );
      expect(t.backend.request, isNull);
    });

    test('rejects an empty photo locally without calling the server', () async {
      final t = setup();

      await expectLater(
        t.repo.submitReport(draft(images: [photo('empty.jpg', const [])])),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('empty'))),
      );
      expect(t.backend.request, isNull);
    });

    test('rejects a photo over the 8 MB limit locally', () async {
      final t = setup();
      final big = [..._jpegBytes, ...List.filled(ReportsRepository.maxImageBytes, 0)];

      await expectLater(
        t.repo.submitReport(draft(images: [photo('big.jpg', big)])),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('8 MB'))),
      );
      expect(t.backend.request, isNull);
    });

    test('rejects more than the maximum number of photos locally', () async {
      final t = setup();
      final images = [
        for (var i = 0; i < ReportsRepository.maxImages + 1; i++) photo('p$i.jpg', _jpegBytes),
      ];

      await expectLater(
        t.repo.submitReport(draft(images: images)),
        throwsA(isA<ApiException>()),
      );
      expect(t.backend.request, isNull);
    });

    test("surfaces the server's own error message as an ApiException", () async {
      final t = setup(status: 400, body: {'detail': 'Unsupported image type: image/gif.'});

      await expectLater(
        t.repo.submitReport(draft(images: [photo('a.png', _pngBytes)])),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Unsupported image type: image/gif.')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });
}
