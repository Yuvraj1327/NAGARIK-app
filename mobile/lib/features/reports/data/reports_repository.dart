import 'package:dio/dio.dart';

import 'package:nagarik/core/constants/api_endpoints.dart';
import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/network/api_client.dart';
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

  Future<Report> submitReport(ReportDraft draft) async {
    final imageParts = await Future.wait(
      draft.images.map(
        (image) => MultipartFile.fromFile(image.path, filename: image.name),
      ),
    );

    final formData = FormData.fromMap({
      'category': draft.category!.name,
      'description': draft.description,
      'city': draft.city,
      'pin_code': draft.pinCode,
      if (draft.latitude != null) 'latitude': draft.latitude.toString(),
      if (draft.longitude != null) 'longitude': draft.longitude.toString(),
      // A List value under one key is Dio's documented way to send
      // multiple files for the same form field — matches FastAPI's
      // `images: list[UploadFile] = File(...)` on the other end.
      'images': imageParts,
    });

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reports,
      data: formData,
    );
    return Report.fromJson(response.data!);
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
