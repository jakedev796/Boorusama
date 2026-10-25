// Project imports:
import '../../../core/tags/metatag/types.dart';

final kSankakuMetatags = {
  const Metatag(
    name: 'order',
    description:
        'Sort by popularity, quality, random, date, id_asc, recently_favorited, recently_voted or duration',
    example: 'order:popularity',
  ),
  const Metatag(
    name: 'rating',
    description: 'Filter by rating: s (safe), q (questionable), e (explicit)',
    example: 'rating:s',
  ),
  const Metatag(
    name: 'date',
    description: 'Posts uploaded within a date range',
    example: 'date:2024-01-01..2024-01-31',
  ),
  const Metatag(
    name: 'threshold',
    description: 'Posts with at least this score',
    example: 'threshold:3',
  ),
  const Metatag(
    name: 'fav',
    description: 'Posts favorited by a user',
    example: 'fav:username',
  ),
  const Metatag(
    name: 'voted',
    description: 'Posts voted on by a user',
    example: 'voted:username',
  ),
  const Metatag(
    name: 'user',
    description: 'Posts uploaded by a user',
    example: 'user:username',
  ),
  const Metatag(
    name: 'pool',
    description: 'Posts in a book',
    example: 'pool:id',
  ),
  const Metatag(
    name: 'file_type',
    description: 'Filter by media type: image or video',
    example: 'file_type:video',
  ),
  const Metatag(
    name: 'duration',
    description: 'Video length in seconds',
    example: 'duration:>30',
  ),
  const Metatag(
    name: 'width',
    description: 'Image width in pixels',
    example: 'width:>=1920',
  ),
  const Metatag(
    name: 'height',
    description: 'Image height in pixels',
    example: 'height:>=1080',
  ),
  const Metatag(
    name: 'mpixels',
    description: 'Image size in megapixels',
    example: 'mpixels:>5',
  ),
  const Metatag(
    name: 'id_range',
    description: 'Posts within an id range',
    example: 'id_range:1000..2000',
  ),
  const Metatag(
    name: 'md5',
    description: 'Post with this file hash',
    example: 'md5:hash',
  ),
  const Metatag(
    name: 'parent',
    description: 'Children of a post, or none for posts without a parent',
    example: 'parent:none',
  ),
  const Metatag(
    name: 'has_children',
    description: 'Posts that have child posts',
    example: 'has_children:true',
  ),
};

/// Shown as chips on the search page; the rest are one tap away in the list.
const kSankakuQuickMetatags = [
  'order',
  'rating',
  'date',
  'threshold',
  'fav',
  'pool',
  'file_type',
];
