// Package imports:
import 'package:dio/dio.dart';

// Project imports:
import 'types/types.dart';

/// The API enforces an offset stepping of 50, so this is both the page size and
/// the only valid offset multiple.
const kPawchivePageSize = 50;

/// The free-text `q` parameter is rejected below this length.
const kPawchiveMinQueryLength = 3;

/// Read-only client for the Pawchive API (`/api/v1`).
///
/// Only anonymous endpoints are covered. The favorites endpoints need a
/// `session` cookie, and the API exposes no way to obtain one — login happens
/// on the website — so they are deliberately left out.
class PawchiveClient {
  PawchiveClient({
    required String baseUrl,
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)),
       _host = _hostOf(baseUrl);

  final Dio _dio;
  final String _host;

  /// Newest posts across every creator. There is no way to order these
  /// differently; the API offers no sort parameter.
  Future<List<PawchivePostDto>> getRecentPosts({
    String? query,
    int? offset,
  }) async {
    final response = await _dio.get(
      '/api/v1/posts',
      queryParameters: {
        'q': ?_sanitizeQuery(query),
        'o': ?_sanitizeOffset(offset),
      },
    );

    return _parsePosts(response.data);
  }

  Future<List<PawchivePostDto>> getCreatorPosts({
    required String service,
    required String creatorId,
    String? query,
    String? tag,
    int? offset,
  }) async {
    final response = await _dio.get(
      '/api/v1/$service/user/$creatorId',
      queryParameters: {
        'q': ?_sanitizeQuery(query),
        'tag': ?tag,
        'o': ?_sanitizeOffset(offset),
      },
    );

    return _parsePosts(response.data);
  }

  Future<PawchivePostDto?> getPost({
    required String service,
    required String creatorId,
    required String postId,
  }) async {
    final response = await _dio.get(
      '/api/v1/$service/user/$creatorId/post/$postId',
    );

    final data = response.data;

    // The endpoint has been observed returning either the post itself or a
    // wrapper object with the post under `post`.
    return switch (data) {
      final Map<String, dynamic> map => PawchivePostDto.fromJson(
        map['post'] is Map<String, dynamic>
            ? map['post'] as Map<String, dynamic>
            : map,
      ),
      final List<dynamic> list when list.isNotEmpty => _parsePosts(
        list,
      ).firstOrNull,
      _ => null,
    };
  }

  /// Every archived creator in one unpaginated response.
  ///
  /// This is a large payload (tens of megabytes) with no sort or page
  /// parameters — the API offers no other way to enumerate or search creators.
  /// Callers must cache the result and should never fetch it eagerly.
  Future<List<PawchiveCreatorDto>> getCreators() async {
    final response = await _dio.get('/api/v1/creators');

    final data = response.data;
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(PawchiveCreatorDto.fromJson)
        .toList();
  }

  Future<PawchiveCreatorDto?> getCreatorProfile({
    required String service,
    required String creatorId,
  }) async {
    final response = await _dio.get(
      '/api/v1/$service/user/$creatorId/profile',
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return null;

    return PawchiveCreatorDto.fromJson(data);
  }

  /// Tags used by one creator. There is no global tag pool.
  Future<List<String>> getCreatorTags({
    required String service,
    required String creatorId,
  }) async {
    final response = await _dio.get(
      '/api/v1/$service/user/$creatorId/tags',
    );

    final data = response.data;
    if (data is! List) return const [];

    return data
        .map(
          (e) => switch (e) {
            final String tag => tag,
            final Map<String, dynamic> map =>
              (map['tag'] ?? map['name'])?.toString(),
            _ => null,
          },
        )
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Scaled-down preview for an attachment [path].
  String thumbnailUrl(String path) =>
      'https://img.$_host/thumbnail/data${_normalizePath(path)}';

  /// Full-size original for an attachment [path].
  ///
  /// The `f` parameter is what makes the download arrive with its real
  /// filename rather than the content hash.
  String fileUrl(String path, {String? fileName}) {
    final url = 'https://file.$_host/data${_normalizePath(path)}';

    if (fileName == null || fileName.isEmpty) return url;

    return '$url?f=${Uri.encodeComponent(fileName)}';
  }

  String creatorIconUrl({
    required String service,
    required String creatorId,
  }) => 'https://$_host/icons/$service/$creatorId';

  /// Web page for a post, for "open in browser" and sharing.
  String postPageUrl({
    required String service,
    required String creatorId,
    required String postId,
  }) => 'https://$_host/$service/user/$creatorId/post/$postId';

  List<PawchivePostDto> _parsePosts(dynamic data) {
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(PawchivePostDto.fromJson)
        .toList();
  }

  /// Queries shorter than [kPawchiveMinQueryLength] are rejected by the API, so
  /// they are dropped rather than sent.
  static String? _sanitizeQuery(String? query) {
    final trimmed = query?.trim();

    if (trimmed == null || trimmed.length < kPawchiveMinQueryLength) {
      return null;
    }

    return trimmed;
  }

  /// Offsets must be non-negative multiples of [kPawchivePageSize].
  static int? _sanitizeOffset(int? offset) {
    if (offset == null || offset <= 0) return null;

    return offset - (offset % kPawchivePageSize);
  }

  /// Attachment paths arrive with a leading slash, but tolerate either.
  static String _normalizePath(String path) =>
      path.startsWith('/') ? path : '/$path';

  /// `https://pawchive.pw/` -> `pawchive.pw`, so the sibling `img.` and
  /// `file.` hosts can be derived instead of hardcoded.
  static String _hostOf(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host;

    if (host == null || host.isEmpty) return 'pawchive.pw';

    return host.startsWith('www.') ? host.substring(4) : host;
  }
}
