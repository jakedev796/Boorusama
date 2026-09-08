// Package imports:
import 'package:booru_clients/pawchive.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/pawchive/posts/parser.dart';
import 'package:boorusama/boorus/pawchive/posts/query.dart';

void main() {
  final client = PawchiveClient(baseUrl: 'https://pawchive.pw/');

  PawchivePostDto post({
    String? id = '100',
    String? service = 'patreon',
    String? user = '7',
    Map<String, dynamic>? file,
    List<Map<String, dynamic>> attachments = const [],
    String? published,
    String? title,
  }) => PawchivePostDto.fromJson({
    'id': id,
    'service': service,
    'user': user,
    'title': title,
    'published': published,
    'file': file ?? <String, dynamic>{},
    'attachments': attachments,
  });

  group('flattening a post into one entry per file', () {
    test('produces one entry for each distinct file', () {
      final result = postDtoToPosts(
        post(
          file: {'name': 'a.png', 'path': '/aa/bb/a.png'},
          attachments: [
            {'name': 'b.png', 'path': '/cc/dd/b.png'},
            {'name': 'c.png', 'path': '/ee/ff/c.png'},
          ],
        ),
        client,
      );

      expect(result.map((e) => e.fileName), ['a.png', 'b.png', 'c.png']);
      expect(result.every((e) => e.fileCount == 3), isTrue);
      expect(result.map((e) => e.fileIndex), [0, 1, 2]);
    });

    test('collapses a headline file repeated as its first attachment', () {
      final result = postDtoToPosts(
        post(
          file: {'name': 'a.png', 'path': '/aa/bb/a.png'},
          attachments: [
            {'name': 'a.png', 'path': '/aa/bb/a.png'},
            {'name': 'b.png', 'path': '/cc/dd/b.png'},
          ],
        ),
        client,
      );

      expect(result.map((e) => e.fileName), ['a.png', 'b.png']);
    });

    test('skips deferred attachments that carry no path', () {
      final result = postDtoToPosts(
        post(
          attachments: [
            {'name': 'pending.zip', 'deferred': true},
            {'name': 'b.png', 'path': '/cc/dd/b.png'},
          ],
        ),
        client,
      );

      expect(result.map((e) => e.fileName), ['b.png']);
    });

    test('yields nothing when a post has no downloadable file', () {
      expect(postDtoToPosts(post(), client), isEmpty);
      expect(
        postDtoToPosts(
          post(
            attachments: [
              {'name': 'pending.zip', 'deferred': true},
            ],
          ),
          client,
        ),
        isEmpty,
      );
    });

    test('yields nothing when the composite identity is incomplete', () {
      final cases = [
        post(id: null),
        post(service: null),
        post(user: null),
      ];

      for (final dto in cases) {
        expect(
          postDtoToPosts(
            dto,
            client,
          ),
          isEmpty,
        );
      }
    });

    test('carries the parent post title and creator onto every entry', () {
      final result = postDtoToPosts(
        post(
          title: 'Lucas x Uma',
          file: {'name': 'a.png', 'path': '/aa/bb/a.png'},
          attachments: [
            {'name': 'b.png', 'path': '/cc/dd/b.png'},
          ],
        ),
        client,
      );

      expect(result.every((e) => e.postTitle == 'Lucas x Uma'), isTrue);
      expect(result.every((e) => e.postKey == 'patreon/7/100'), isTrue);
    });
  });

  group('preview urls by file type', () {
    final cases = [
      (path: '/aa/bb/x.png', renderable: true),
      (path: '/aa/bb/x.jpg', renderable: true),
      (path: '/aa/bb/x.gif', renderable: true),
      (path: '/aa/bb/x.mp4', renderable: true),
      (path: '/aa/bb/x.clip', renderable: false),
      (path: '/aa/bb/x.zip', renderable: false),
      (path: '/aa/bb/x.psd', renderable: false),
      (path: '/aa/bb/x', renderable: false),
    ];

    for (final c in cases) {
      test('${c.path} is ${c.renderable ? '' : 'not '}previewable', () {
        final result = postDtoToPosts(
          post(file: {'name': 'x', 'path': c.path}),
          client,
        ).single;

        expect(result.isRenderable, c.renderable);

        // A non-previewable file must not point the grid at an image that
        // would 404; it still has to be downloadable.
        expect(result.thumbnailImageUrl.isNotEmpty, c.renderable);
        expect(result.sampleImageUrl.isNotEmpty, c.renderable);
        expect(result.originalImageUrl, isNotEmpty);
      });
    }

    test('builds preview and original urls on their own hosts', () {
      final result = postDtoToPosts(
        post(file: {'name': 'my file.png', 'path': '/aa/bb/hash.png'}),
        client,
      ).single;

      expect(
        result.thumbnailImageUrl,
        'https://img.pawchive.pw/thumbnail/data/aa/bb/hash.png',
      );
      expect(
        result.originalImageUrl,
        'https://file.pawchive.pw/data/aa/bb/hash.png?f=my%20file.png',
      );
    });

    test('exposes a video url only for video files', () {
      final video = postDtoToPosts(
        post(file: {'name': 'v.mp4', 'path': '/aa/bb/v.mp4'}),
        client,
      ).single;
      final image = postDtoToPosts(
        post(file: {'name': 'i.png', 'path': '/aa/bb/i.png'}),
        client,
      ).single;

      expect(video.videoUrl, isNotEmpty);
      expect(image.videoUrl, isEmpty);
    });
  });

  group('per-file ids', () {
    test('differ between files of the same post', () {
      final result = postDtoToPosts(
        post(
          file: {'name': 'a.png', 'path': '/aa/bb/a.png'},
          attachments: [
            {'name': 'b.png', 'path': '/cc/dd/b.png'},
            {'name': 'c.png', 'path': '/ee/ff/c.png'},
          ],
        ),
        client,
      );

      expect(result.map((e) => e.id).toSet(), hasLength(3));
    });

    test('are unchanged when the same file is parsed again', () {
      int idOf() => syntheticPostId(
        service: 'patreon',
        creatorId: '7',
        postId: '100',
        fileIndex: 2,
      );

      expect(idOf(), idOf());
    });

    test('are stable for non-numeric post ids', () {
      int idOf() => syntheticPostId(
        service: 'gumroad',
        creatorId: 'abc',
        postId: 'not-a-number',
        fileIndex: 0,
      );

      expect(idOf(), idOf());
      expect(idOf(), greaterThan(0));
    });

    test('do not collide between numeric and non-numeric schemes', () {
      final numeric = syntheticPostId(
        service: 'patreon',
        creatorId: '7',
        postId: '100',
        fileIndex: 0,
      );
      final hashed = syntheticPostId(
        service: 'gumroad',
        creatorId: 'abc',
        postId: 'xyz',
        fileIndex: 0,
      );

      expect(numeric, isNot(hashed));
    });

    test('differ between distinct posts sharing a file index', () {
      final first = syntheticPostId(
        service: 'patreon',
        creatorId: '7',
        postId: '100',
        fileIndex: 0,
      );
      final second = syntheticPostId(
        service: 'patreon',
        creatorId: '7',
        postId: '101',
        fileIndex: 0,
      );

      expect(first, isNot(second));
    });
  });

  group('reading extension and hash from a stored path', () {
    final cases = [
      (path: '/38/98/abc123.clip', extension: 'clip', hash: 'abc123'),
      (path: '/aa/bb/x.JPEG', extension: 'jpeg', hash: 'x'),
      (path: 'bare.png', extension: 'png', hash: 'bare'),
      (path: '/aa/bb/noext', extension: '', hash: 'noext'),
      (path: '/aa/bb/trailing.', extension: '', hash: 'trailing'),
    ];

    for (final c in cases) {
      test('${c.path} reads as "${c.extension}" and "${c.hash}"', () {
        expect(extensionOf(c.path), c.extension);
        expect(hashOf(c.path), c.hash);
      });
    }
  });

  group('resolving a search into api parameters', () {
    test('scopes to a creator given a creator meta-tag', () {
      final query = PawchiveQuery.parse(['creator:patreon/92513615']);

      expect(query.hasCreator, isTrue);
      expect(query.service, 'patreon');
      expect(query.creatorId, '92513615');
      expect(query.text, isNull);
    });

    test('treats unprefixed terms as free text', () {
      final query = PawchiveQuery.parse(['sketch', 'wip']);

      expect(query.hasCreator, isFalse);
      expect(query.text, 'sketch wip');
    });

    test('separates a creator tag filter from free text', () {
      final query = PawchiveQuery.parse([
        'creator:fanbox/21101760',
        'tag:sketch',
        'clip',
      ]);

      expect(query.service, 'fanbox');
      expect(query.creatorId, '21101760');
      expect(query.tag, 'sketch');
      expect(query.text, 'clip');
    });

    test('ignores a creator without a service, which would be ambiguous', () {
      final cases = ['creator:92513615', 'creator:', 'creator:/', 'creator:x/'];

      for (final entry in cases) {
        expect(PawchiveQuery.parse([entry]).hasCreator, isFalse);
      }
    });

    test('lets a later creator replace an earlier one', () {
      final query = PawchiveQuery.parse([
        'creator:patreon/1',
        'creator:fanbox/2',
      ]);

      expect(query.service, 'fanbox');
      expect(query.creatorId, '2');
    });

    test('round-trips a creator through its meta-tag form', () {
      final tag = PawchiveQuery.creatorTag(
        service: 'patreon',
        creatorId: '92513615',
      );
      final query = PawchiveQuery.parse([tag]);

      expect(query.service, 'patreon');
      expect(query.creatorId, '92513615');
    });

    test('ignores blank entries', () {
      final query = PawchiveQuery.parse(['', '   ']);

      expect(query.hasCreator, isFalse);
      expect(query.text, isNull);
    });
  });
}
