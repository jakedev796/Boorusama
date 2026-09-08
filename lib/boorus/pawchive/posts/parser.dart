// Package imports:
import 'package:booru_clients/pawchive.dart';

// Project imports:
import '../../../core/posts/post/types.dart';
import '../../../core/posts/rating/types.dart';
import '../../../core/posts/sources/types.dart';
import 'types.dart';

/// Upper bound on files per post used to keep synthetic ids collision-free.
///
/// Posts beyond this many files fall back to the hashed id path.
const _kFileIndexSpace = 1000;

/// Extensions the app can display. Everything else is downloadable but gets a
/// placeholder rather than a broken preview — Pawchive only generates
/// thumbnails for media, and requesting one for e.g. a `.clip` file 404s.
const _kRenderableFormats = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'avif',
  'bmp',
  'jxl',
  'mp4',
  'webm',
  'm4v',
  'mov',
};

/// Flattens a post into one [PawchivePost] per available file.
///
/// Returns an empty list when nothing is downloadable, which happens for
/// text-only posts and for posts whose files are all still deferred.
List<PawchivePost> postDtoToPosts(
  PawchivePostDto dto,
  PawchiveClient client, {
  PostMetadata? metadata,
}) {
  final service = dto.service;
  final creatorId = dto.user;
  final postId = dto.id;

  if (service == null || creatorId == null || postId == null) return const [];

  final files = dto.allFiles;
  final createdAt = _parseDate(dto.published) ?? _parseDate(dto.added);

  return [
    for (final (index, file) in files.indexed)
      _toPost(
        dto: dto,
        file: file,
        client: client,
        service: service,
        creatorId: creatorId,
        postId: postId,
        index: index,
        fileCount: files.length,
        createdAt: createdAt,
        metadata: metadata,
      ),
  ];
}

/// Flattens a page of posts, preserving order.
List<PawchivePost> postDtosToPosts(
  List<PawchivePostDto> dtos,
  PawchiveClient client, {
  PostMetadata? metadata,
}) => [
  for (final dto in dtos) ...postDtoToPosts(dto, client, metadata: metadata),
];

PawchivePost _toPost({
  required PawchivePostDto dto,
  required PawchiveAttachmentDto file,
  required PawchiveClient client,
  required String service,
  required String creatorId,
  required String postId,
  required int index,
  required int fileCount,
  required DateTime? createdAt,
  required PostMetadata? metadata,
}) {
  final path = file.path!;
  final format = extensionOf(path);
  final renderable = _kRenderableFormats.contains(format);
  final fileUrl = client.fileUrl(path, fileName: file.name);

  // Non-renderable files get empty preview urls so the grid shows a
  // placeholder. The original url stays populated so downloads still work.
  final thumbnailUrl = renderable ? client.thumbnailUrl(path) : '';
  final isVideoFormat = _kVideoFormats.contains(format);

  return PawchivePost(
    id: syntheticPostId(
      service: service,
      creatorId: creatorId,
      postId: postId,
      fileIndex: index,
    ),
    thumbnailImageUrl: thumbnailUrl,
    sampleImageUrl: thumbnailUrl,
    originalImageUrl: fileUrl,
    tags: const {},
    rating: Rating.unknown,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: fileCount > 1,
    source: PostSource.from(
      client.postPageUrl(
        service: service,
        creatorId: creatorId,
        postId: postId,
      ),
    ),
    score: 0,
    duration: 0,
    fileSize: 0,
    format: format,
    hasSound: isVideoFormat ? null : false,
    height: 0,
    md5: hashOf(path),
    videoThumbnailUrl: thumbnailUrl,
    videoUrl: isVideoFormat ? fileUrl : '',
    width: 0,
    uploaderId: null,
    uploaderName: creatorId,
    createdAt: createdAt,
    metadata: metadata,
    service: service,
    creatorId: creatorId,
    postId: postId,
    postTitle: dto.title,
    fileName: file.name,
    fileIndex: index,
    fileCount: fileCount,
    isRenderable: renderable,
  );
}

const _kVideoFormats = <String>{'mp4', 'webm', 'm4v', 'mov'};

/// A unique, stable id for one file of one post.
///
/// [Post.id] is an `int` and [SimplePost] compares by it alone, while the grid
/// both dedupes on it and uses it as a widget key. Siblings from the same post
/// must therefore not share an id. Ids also outlive the session because
/// bookmarks persist them, so this has to be deterministic — no `hashCode`.
///
/// Numeric post ids get room reserved for their file index. Services with
/// non-numeric ids, and posts with more files than [_kFileIndexSpace], fall
/// back to a hash of the full composite key.
int syntheticPostId({
  required String service,
  required String creatorId,
  required String postId,
  required int fileIndex,
}) {
  final numericId = int.tryParse(postId);

  if (numericId != null && numericId > 0 && fileIndex < _kFileIndexSpace) {
    return numericId * _kFileIndexSpace + fileIndex;
  }

  return _stableHash('$service/$creatorId/$postId#$fileIndex');
}

/// FNV-1a, 32-bit. Deterministic across runs and releases, unlike
/// `Object.hash`, which is what makes it safe for persisted ids.
int _stableHash(String value) {
  var hash = 0x811c9dc5;

  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }

  // Keep clear of the numeric-id space so the two schemes cannot collide.
  return hash | 0x40000000;
}

/// `/38/98/<sha256>.clip` -> `clip`. Empty when there is no extension.
String extensionOf(String path) {
  final lastSlash = path.lastIndexOf('/');
  final name = lastSlash == -1 ? path : path.substring(lastSlash + 1);
  final dot = name.lastIndexOf('.');

  if (dot == -1 || dot == name.length - 1) return '';

  return name.substring(dot + 1).toLowerCase();
}

/// `/38/98/<sha256>.clip` -> `<sha256>`.
///
/// Pawchive shards files by the first two byte-pairs of their content hash, so
/// the basename is the hash itself.
String hashOf(String path) {
  final lastSlash = path.lastIndexOf('/');
  final name = lastSlash == -1 ? path : path.substring(lastSlash + 1);
  final dot = name.lastIndexOf('.');

  return dot == -1 ? name : name.substring(0, dot);
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;

  return DateTime.tryParse(value);
}
