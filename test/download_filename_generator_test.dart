// Package imports:
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/boorus/pawchive/posts/types.dart';
import 'package:boorusama/boorus/pixiv/pixiv_repository.dart';
import 'package:boorusama/boorus/pixiv/posts/parser.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/downloads/filename/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:booru_clients/pixiv.dart';

void main() {
  group('DownloadFileNameBuilder', () {
    final builder = DownloadFileNameBuilder<Post>(
      defaultFileNameFormat: kDefaultCustomDownloadFileNameFormat,
      defaultBulkDownloadFileNameFormat: kDefaultCustomDownloadFileNameFormat,
      sampleData: kDanbooruPostSamples,
      tokenHandlers: const [],
    );

    const config = BooruConfigDownload(
      fileNameFormat: null,
      bulkFileNameFormat: null,
      location: null,
    );

    test('uses default bulk format when config has no custom format', () async {
      final fileName = await builder.generateForBulkDownload(
        Settings.defaultSettings,
        config,
        _TestPost(format: 'jpg'),
        downloadUrl: 'http://127.0.0.1:45869/get_files/file?file_id=42',
      );

      expect(fileName, '42_01234567.jpg');
    });

    test('uses post format when download url has no extension', () async {
      final fileName = await builder.generate(
        Settings.defaultSettings,
        config,
        _TestPost(format: '.png'),
        downloadUrl: 'http://127.0.0.1:45869/get_files/file?file_id=42',
      );

      expect(fileName, '42_01234567.png');
    });
  });

  group('custom engine token handlers', () {
    const config = BooruConfigDownload(
      fileNameFormat: null,
      bulkFileNameFormat: null,
      location: null,
    );

    test('resolves a custom token handler name in the format string', () async {
      final builder = DownloadFileNameBuilder<Post>(
        defaultFileNameFormat: '{engine_token}.{extension}',
        defaultBulkDownloadFileNameFormat: '{engine_token}.{extension}',
        sampleData: const [],
        tokenHandlers: [
          TokenHandler('engine_token', (post, options) => 'custom-value'),
        ],
      );

      final fileName = await builder.generate(
        Settings.defaultSettings,
        config,
        _TestPost(format: 'jpg'),
        downloadUrl: 'http://127.0.0.1:45869/get_files/file?file_id=42',
      );

      expect(fileName, 'custom-value.jpg');
    });

    test(
      "Pixiv's default format produces a distinct filename per page of the same illust",
      () async {
        final builder = DownloadFileNameBuilder<Post>(
          defaultFileNameFormat: kPixivCustomDownloadFileNameFormat,
          defaultBulkDownloadFileNameFormat: kPixivCustomDownloadFileNameFormat,
          sampleData: const [],
          hasMd5: false,
          extensionHandler: (post, config) => post.format.startsWith('.')
              ? post.format.substring(1)
              : post.format,
          tokenHandlers: [
            TokenHandler('illust_id', (post, options) {
              return post is PixivPost ? post.illustId.toString() : '';
            }),
            TokenHandler('page', (post, options) {
              return post is PixivPost ? post.pageIndex.toString() : '';
            }),
            TokenHandler('user_id', (post, options) {
              return post is PixivPost ? post.userId.toString() : '';
            }),
            TokenHandler('user_name', (post, options) {
              return post is PixivPost ? post.userName : '';
            }),
          ],
        );

        final posts = illustDtoToPosts(
          PixivIllustDto.fromJson({
            'id': 56001614,
            'title': 'title',
            'type': 'illust',
            'image_urls': {'square_medium': 'sq.jpg', 'medium': 'med.jpg'},
            'user': {'id': 5, 'name': 'Artist', 'account': 'artist_acc'},
            'tags': const [],
            'page_count': 2,
            'width': 100,
            'height': 200,
            'sanity_level': 2,
            'x_restrict': 0,
            'meta_single_page': <String, dynamic>{},
            'meta_pages': [
              {
                'image_urls': {
                  'original': 'https://i.pximg.net/img/56001614_p0.png',
                },
              },
              {
                'image_urls': {
                  'original': 'https://i.pximg.net/img/56001614_p1.png',
                },
              },
            ],
            'visible': true,
            'is_muted': false,
          }),
        );

        expect(posts, hasLength(2));

        final fileNames = [
          for (final post in posts)
            await builder.generate(
              Settings.defaultSettings,
              config,
              post,
              downloadUrl: post.originalImageUrl,
            ),
        ];

        expect(fileNames, ['56001614_p0.png', '56001614_p1.png']);
        expect(fileNames.toSet(), hasLength(2));
      },
    );

    test('resolves pawchive custom tokens in a user-supplied format', () async {
      final builder = DownloadFileNameBuilder<Post>(
        defaultFileNameFormat: kDefaultCustomDownloadFileNameFormat,
        defaultBulkDownloadFileNameFormat: kDefaultCustomDownloadFileNameFormat,
        sampleData: const [],
        hasRating: false,
        extensionHandler: (post, config) => post.format,
        tokenHandlers: [
          TokenHandler('file_name', (post, options) {
            return post is PawchivePost ? post.fileName ?? '' : '';
          }),
          TokenHandler('creator', (post, options) {
            return post is PawchivePost ? post.creatorId : '';
          }),
          TokenHandler('service', (post, options) {
            return post is PawchivePost ? post.service : '';
          }),
          TokenHandler('post_id', (post, options) {
            return post is PawchivePost ? post.postId : '';
          }),
        ],
      );

      final post = PawchivePost(
        id: 1,
        thumbnailImageUrl: '',
        sampleImageUrl: '',
        originalImageUrl: '',
        tags: const {},
        rating: Rating.general,
        hasComment: false,
        isTranslated: false,
        hasParentOrChildren: false,
        source: PostSource.none(),
        score: 0,
        duration: 0,
        fileSize: 0,
        format: 'zip',
        hasSound: null,
        height: 100,
        md5: '',
        videoThumbnailUrl: '',
        videoUrl: '',
        width: 100,
        uploaderId: null,
        metadata: null,
        service: 'patreon',
        creatorId: 'creator1',
        postId: 'post1',
        fileName: 'archive.zip',
        fileIndex: 0,
        fileCount: 1,
        isRenderable: false,
      );

      final fileName = await builder.generate(
        Settings.defaultSettings,
        const BooruConfigDownload(
          fileNameFormat: '{service}_{creator}_{post_id}_{file_name}',
          bulkFileNameFormat: null,
          location: null,
        ),
        post,
        downloadUrl: 'https://example.com/archive.zip',
      );

      expect(fileName, 'patreon_creator1_post1_archive.zip');
    });
  });
}

class _TestPost extends SimplePost {
  _TestPost({
    required super.format,
  }) : super(
         id: 42,
         thumbnailImageUrl: '',
         sampleImageUrl: '',
         originalImageUrl: '',
         tags: const {},
         rating: Rating.general,
         hasComment: false,
         isTranslated: false,
         hasParentOrChildren: false,
         source: PostSource.none(),
         score: 0,
         duration: 0,
         fileSize: 0,
         hasSound: null,
         height: 100,
         md5: '0123456789abcdef0123456789abcdef',
         videoThumbnailUrl: '',
         videoUrl: '',
         width: 100,
         uploaderId: null,
         metadata: null,
       );
}
