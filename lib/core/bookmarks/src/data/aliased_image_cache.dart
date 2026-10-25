// Dart imports:
import 'dart:async';
import 'dart:typed_data';

// Package imports:
import 'package:cache_manager/cache_manager.dart';

/// Stores and serves a refreshed URL under the cache key of the URL it
/// replaces, so a bookmark keeps a single cached file however often its
/// signed URLs are renewed.
class AliasedImageCacheManager implements ImageCacheManager {
  AliasedImageCacheManager({
    required this.inner,
    required this.aliases,
    this.rejectSave,
  });

  final ImageCacheManager inner;

  /// Maps a refreshed URL to the URL whose cache key it should use.
  final Map<String, String> aliases;

  /// Bytes that must not be cached, such as an expired-link placeholder that
  /// would otherwise stay in place of the real file.
  final bool Function(Uint8List bytes)? rejectSave;

  @override
  String generateCacheKey(String url, {String? customKey}) =>
      inner.generateCacheKey(aliases[url] ?? url, customKey: customKey);

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) =>
      inner.getCachedFilePath(key, maxAge: maxAge);

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      inner.getCachedFileBytes(key, maxAge: maxAge);

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {
    if (rejectSave?.call(bytes) ?? false) return;

    await inner.saveFile(key, bytes);
  }

  @override
  FutureOr<bool> hasValidCache(String key, {Duration? maxAge}) =>
      inner.hasValidCache(key, maxAge: maxAge);

  @override
  Future<void> clearCache(String key) => inner.clearCache(key);

  @override
  Future<void> clearAllCache() => inner.clearAllCache();

  @override
  void invalidateCacheDirectory() => inner.invalidateCacheDirectory();

  // The inner manager is shared app-wide; its owner disposes it.
  @override
  Future<void> dispose() async {}
}
