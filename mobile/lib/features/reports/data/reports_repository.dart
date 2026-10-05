import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:image_picker/image_picker.dart';

import 'package:nagarik/core/constants/api_endpoints.dart';
import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/report_draft.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/domain/report_stats.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';

class ReportsRepository {
  ReportsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Mirrors the backend's `MAX_IMAGES` (see
  /// backend/app/services/reports_service.py) so the UI can stop the user
  /// well before hitting a 400 from the server.
  static const int maxImages = 5;

  /// Mirrors the backend's `MAX_IMAGE_BYTES` (8 MB per image).
  static const int maxImageBytes = 8 * 1024 * 1024;

  /// The global 15s timeouts in `ApiClient` are far too short for up to five
  /// photos: the backend uploads them to Storage one by one before it
  /// answers. A timeout here would also invite a retry that creates a
  /// duplicate report, so submissions get a much longer window.
  static const Duration _submitTimeout = Duration(minutes: 2);

  Future<Report> submitReport(ReportDraft draft) async {
    final category = draft.category;
    if (category == null) {
      throw const ApiException(message: 'Please select a category.');
    }
    if (draft.images.length > maxImages) {
      throw const ApiException(message: 'You can attach up to $maxImages photos.');
    }

    final imageParts = <MultipartFile>[];
    for (final image in draft.images) {
      imageParts.add(await _toMultipart(image));
    }

    final formData = FormData.fromMap({
      'category': category.name,
      'description': draft.description.trim(),
      'city': draft.city.trim(),
      'pin_code': draft.pinCode.trim(),
      // Coordinates are only valid as a pair; never send half of one.
      if (draft.latitude != null && draft.longitude != null) ...{
        'latitude': draft.latitude.toString(),
        'longitude': draft.longitude.toString(),
      },
      // A List value under one key is Dio's documented way to send
      // multiple files for the same form field — matches FastAPI's
      // `images: list[UploadFile] = File(...)` on the other end.
      'images': imageParts,
    });

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reports,
      data: formData,
      options: Options(
        sendTimeout: _submitTimeout,
        receiveTimeout: _submitTimeout,
      ),
    );
    return Report.fromJson(response.data!);
  }

  /// Builds the multipart part for one picked photo with an EXPLICIT
  /// content type, and rejects what the backend would reject — before
  /// uploading anything.
  ///
  /// Dio otherwise guesses the type from the file *name*, falling back to
  /// `application/octet-stream` when there's no recognizable extension
  /// (common for gallery picks on Android), and the backend answers that
  /// with a 400 "Unsupported image type". The type is read from the file's
  /// own first bytes instead, so it always matches the real content.
  Future<MultipartFile> _toMultipart(XFile image) async {
    final length = await image.length();
    if (length == 0) {
      throw const ApiException(message: 'One of the selected photos is empty.');
    }
    if (length > maxImageBytes) {
      throw const ApiException(message: 'Each photo must be smaller than 8 MB.');
    }

    final header = <int>[];
    await for (final chunk in image.openRead(0, 12)) {
      header.addAll(chunk);
      if (header.length >= 12) break;
    }
    final contentType = detectImageContentType(header);
    if (contentType == null) {
      throw const ApiException(
        message: 'Only JPEG, PNG or WebP photos can be attached.',
      );
    }

    return MultipartFile.fromFile(
      image.path,
      filename: image.name.isEmpty ? 'photo.${contentType.subtype}' : image.name,
      contentType: contentType,
    );
  }

  /// JPEG / PNG / WebP by magic bytes (the only types the backend accepts),
  /// or null for anything else (e.g. HEIC, GIF, a non-image).
  @visibleForTesting
  static DioMediaType? detectImageContentType(List<int> bytes) {
    bool startsWith(List<int> prefix) =>
        bytes.length >= prefix.length &&
        List.generate(prefix.length, (i) => bytes[i] == prefix[i]).every((m) => m);

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return DioMediaType('image', 'jpeg');
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return DioMediaType('image', 'png');
    }
    // WebP: "RIFF" <4-byte size> "WEBP"
    if (bytes.length >= 12 &&
        startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return DioMediaType('image', 'webp');
    }
    return null;
  }

  /// Fetches a single report by id (Step 7) — public, works whether or not
  /// the caller is signed in.
  Future<Report> getReport(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${ApiEndpoints.reports}/$id',
    );
    return Report.fromJson(response.data!);
  }

  /// Browses/searches reports (Step 7 baseline feed, Step 8 filters).
  ///
  /// - Leaving every filter unset returns the most recent reports overall
  ///   (the home feed).
  /// - [mine] returns only the signed-in caller's own reports (requires a
  ///   session — used by the Profile tab's report history).
  /// - [latitude]/[longitude] (with optional [radiusKm]) switch to a
  ///   nearest-first search within that radius instead of recency order —
  ///   both must be given together or neither.
  Future<ReportsPage> getReports({
    ReportCategory? category,
    ReportStatus? status,
    String? city,
    String? pinCode,
    String? search,
    bool mine = false,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.reports,
      queryParameters: {
        if (category != null) 'category': category.name,
        if (status != null) 'status': Report.statusToWire(status),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (pinCode != null && pinCode.trim().isNotEmpty) 'pin_code': pinCode.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (mine) 'mine': true,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusKm != null) 'radius_km': radiusKm,
        'limit': limit,
        'offset': offset,
      },
    );
    return ReportsPage.fromJson(response.data!);
  }

  /// Per-status counts of the signed-in caller's own reports (Profile
  /// screen's stat tiles). Requires a session — the same one every call in
  /// this class relies on `ApiClient`'s auto-attached bearer token for.
  Future<ReportStats> getReportStats() async {
    final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.reportStats);
    return ReportStats.fromJson(response.data!);
  }

  /// Lean report data for the Nearby/Discovery map (Location Discovery &
  /// Home upgrade) — same filters as [getReports], but the response has no
  /// description or images (see `ReportMarker`'s doc comment), so this is
  /// what the map view calls instead of [getReports] to avoid downloading
  /// data no pin actually displays. Public, same as [getReports].
  Future<List<ReportMarker>> getReportMarkers({
    ReportCategory? category,
    ReportStatus? status,
    String? city,
    String? pinCode,
    String? search,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.reportMarkers,
      queryParameters: {
        if (category != null) 'category': category.name,
        if (status != null) 'status': Report.statusToWire(status),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (pinCode != null && pinCode.trim().isNotEmpty) 'pin_code': pinCode.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusKm != null) 'radius_km': radiusKm,
      },
    );
    final items = response.data!['items'] as List<dynamic>;
    return items
        .map((item) => ReportMarker.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// The signed-in caller's bookmarked reports (Profile -> My Activity ->
  /// Saved Reports), most recently saved first. Requires a session, same as
  /// [getReportStats].
  Future<ReportsPage> getSavedReports({int limit = 20, int offset = 0}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.savedReports,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ReportsPage.fromJson(response.data!);
  }

  /// Bookmarks a report for the signed-in caller (Report Sharing & Saved
  /// Reports upgrade). Idempotent on the backend — calling this for an
  /// already-saved report succeeds rather than erroring, so callers never
  /// need to check "is it saved?" first just to avoid a duplicate-save error.
  Future<void> saveReport(String reportId) async {
    await _apiClient.post<Map<String, dynamic>>('${ApiEndpoints.reports}/$reportId/save');
  }

  /// Removes a bookmark. Also idempotent — unsaving a report that isn't
  /// currently saved succeeds rather than erroring.
  Future<void> unsaveReport(String reportId) async {
    await _apiClient.delete<void>('${ApiEndpoints.reports}/$reportId/save');
  }
}
