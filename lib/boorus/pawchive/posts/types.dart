// Project imports:
import '../../../core/posts/post/types.dart';

/// One file belonging to one archived post.
///
/// A Pawchive post can carry several files, but [Post] models exactly one, so
/// each file becomes its own [PawchivePost]. [postId] is therefore shared
/// between siblings while [id] is unique — see `syntheticPostId` in
/// `parser.dart` for why that matters.
class PawchivePost extends SimplePost {
  PawchivePost({
    required super.id,
    required super.thumbnailImageUrl,
    required super.sampleImageUrl,
    required super.originalImageUrl,
    required super.tags,
    required super.rating,
    required super.hasComment,
    required super.isTranslated,
    required super.hasParentOrChildren,
    required super.source,
    required super.score,
    required super.duration,
    required super.fileSize,
    required super.format,
    required super.hasSound,
    required super.height,
    required super.md5,
    required super.videoThumbnailUrl,
    required super.videoUrl,
    required super.width,
    required super.uploaderId,
    required super.metadata,
    required this.service,
    required this.creatorId,
    required this.postId,
    required this.fileName,
    required this.fileIndex,
    required this.fileCount,
    required this.isRenderable,
    this.postTitle,
    super.createdAt,
    super.uploaderName,
  });

  /// The upstream platform this was archived from, e.g. `patreon`, `fanbox`.
  final String service;

  /// Creator id within [service]. Not globally unique on its own.
  final String creatorId;

  /// The archived post's real id, as a string — some services use
  /// non-numeric ids, and siblings from the same post share this value.
  final String postId;

  /// Original filename, used so downloads keep a real name instead of a hash.
  final String? fileName;

  /// Position of this file within its post, zero-based.
  final int fileIndex;

  /// How many files the parent post had in total.
  final int fileCount;

  /// Whether this file is an image or video the app can display. Archives,
  /// `.clip` files and similar are downloadable but have no preview, so they
  /// render as a placeholder instead.
  final bool isRenderable;

  final String? postTitle;

  /// Stable identity of the parent post across services.
  String get postKey => '$service/$creatorId/$postId';

  /// True when the parent post had more than one file.
  bool get hasSiblings => fileCount > 1;
}
