import 'dart:convert';

import 'package:booru_clients/pixiv.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'mock_pixiv_server.dart';

void main() {
  group('PixivClient requests', () {
    late MockPixivServer server;
    late String baseUrl;
    late Dio dio;

    setUp(() async {
      server = MockPixivServer();
      baseUrl = await server.start();
      dio = Dio(
        BaseOptions(baseUrl: baseUrl, headers: {'X-App-Header': 'keep-me'}),
      );
    });

    tearDown(() async {
      await server.stop();
    });

    test(
      'attaches every required header and leaves the shared Dio untouched',
      () async {
        final originalHeaders = Map<String, dynamic>.from(dio.options.headers);
        final client = PixivClient(
          dio: dio,
          accessToken: 'token-abc',
          acceptLanguage: 'ja-JP',
        );

        await client.getRanking(mode: PixivRankingMode.day);

        final headers = server.lastRequest!.headers;
        expect(headers['authorization'], 'Bearer token-abc');
        expect(headers['user-agent'], kPixivUserAgent);
        expect(headers['app-os'], kPixivAppOs);
        expect(headers['app-os-version'], kPixivAppOsVersion);
        expect(headers['app-version'], kPixivAppVersion);
        expect(headers['accept-language'], 'ja-JP');
        expect(headers['referer'], kPixivApiReferer);

        final clientTime = headers['x-client-time'];
        expect(clientTime, isNotNull);
        final expectedHash = md5
            .convert(utf8.encode('$clientTime$kPixivHashSecret'))
            .toString();
        expect(headers['x-client-hash'], expectedHash);

        expect(dio.options.headers, originalHeaders);
      },
    );

    test('formats a ranking date as YYYY-MM-DD when one is given', () async {
      final client = PixivClient(dio: dio, accessToken: 'token');

      await client.getRanking(
        mode: PixivRankingMode.week,
        date: DateTime(2026, 3, 4),
      );

      expect(server.lastRequest!.url.queryParameters['date'], '2026-03-04');
    });

    test(
      'omits the ranking date parameter entirely when none is given',
      () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getRanking(mode: PixivRankingMode.day);

        expect(
          server.lastRequest!.url.queryParameters.containsKey('date'),
          false,
        );
      },
    );

    final offsetCases = [
      (page: 1, expectedOffset: '0'),
      (page: 2, expectedOffset: '30'),
      (page: 5, expectedOffset: '120'),
    ];
    for (final c in offsetCases) {
      test('computes offset ${c.expectedOffset} for page ${c.page}', () async {
        final client = PixivClient(dio: dio, accessToken: 'token');

        await client.getRanking(mode: PixivRankingMode.day, page: c.page);

        expect(
          server.lastRequest!.url.queryParameters['offset'],
          c.expectedOffset,
        );
      });
    }

    final hasMoreCases = [
      (
        body: '{"illusts": [], "next_url": "https://app-api.pixiv.net/next"}',
        expected: true,
      ),
      (body: '{"illusts": [], "next_url": null}', expected: false),
    ];
    for (final c in hasMoreCases) {
      test('reports hasMore as ${c.expected} from next_url', () async {
        server.responseBody = c.body;
        final client = PixivClient(dio: dio, accessToken: 'token');

        final result = await client.getRanking(mode: PixivRankingMode.day);

        expect(result.hasMore, c.expected);
      });
    }

    test(
      'raises when the body carries an error envelope with HTTP 200',
      () async {
        server.responseBody = '{"error": {"message": "something broke"}}';
        final client = PixivClient(dio: dio, accessToken: 'token');

        await expectLater(
          client.getRanking(mode: PixivRankingMode.day),
          throwsA(isA<PixivApiException>()),
        );
      },
    );

    test(
      'raises a rate-limit exception when the error message says so',
      () async {
        server.responseBody = '{"error": {"message": "Rate Limit exceeded"}}';
        final client = PixivClient(dio: dio, accessToken: 'token');

        await expectLater(
          client.getRanking(mode: PixivRankingMode.day),
          throwsA(isA<PixivRateLimitException>()),
        );
      },
    );

    test(
      'never leaks the authorization header value in a failed request\'s exception',
      () async {
        await server.stop();
        final deadDio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
        final client = PixivClient(
          dio: deadDio,
          accessToken: 'super-secret-token',
        );

        try {
          await client.getRanking(mode: PixivRankingMode.day);
          fail('expected a request failure');
        } catch (e) {
          expect(e.toString().contains('super-secret-token'), false);
        }
      },
    );
  });
}
