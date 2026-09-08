// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/configs/config/types.dart';
import '../../core/ddos/handler/providers.dart';
import '../../core/http/client/providers.dart';
import '../../core/http/client/types.dart';
import '../../foundation/loggers.dart';

final pixivClientProvider = Provider.family<PixivClient, BooruConfigAuth>((
  ref,
  config,
) {
  final dio = ref.watch(pixivDioProvider(config));

  // SEAM (S3): S1's `PixivClient` is immutable per access token — S3 reads
  // the live, rotated access token here (persisted alongside `config` by its
  // auth interceptor) instead of `config.apiKey` directly, since `apiKey`
  // holds the long-lived *refresh* token, not the short-lived access token.
  // Passing it through as-is for now keeps this provider wired without
  // implementing any refresh logic, which S3 owns entirely.
  return PixivClient(
    accessToken: config.apiKey ?? '',
    dio: dio,
  );
});

final pixivDioProvider = Provider.family<Dio, BooruConfigAuth>((ref, config) {
  final ddosProtectionHandler = ref.watch(httpDdosProtectionBypassProvider);
  final loggerService = ref.watch(loggerProvider);

  final dio = newDio(
    options: DioOptions(
      ddosProtectionHandler: ddosProtectionHandler,
      userAgent: ref.watch(defaultUserAgentProvider),
      loggerService: loggerService,
      networkProtocolInfo: ref.watch(
        defaultNetworkProtocolInfoProvider(config),
      ),
      baseUrl: kPixivApiBaseUrl,
      proxySettings: config.proxySettings,
      // FIX 7b: `skipCertificateVerification` is deliberately never passed
      // here (the default is `false` and stays that way), even though the
      // per-config UI exposes a toggle for it — this Dio carries a
      // full-account bearer token and must never allow that toggle to
      // disable TLS validation on it.
    ),
    additionalInterceptors: [
      // FIX 7c: conservative bound (eshuushuu's 30/60s), not the app's
      // default 10 requests/second — Pixiv's app-api is more sensitive to
      // bursts than the boorus this default was tuned for.
      SlidingWindowRateLimitInterceptor(
        config: const SlidingWindowRateLimitConfig(
          requestsPerWindow: 30,
          windowSizeMs: 60000,
          maxDelayMs: 10000,
        ),
      ),
      // FIX 7c: a "Rate Limit" response (or a plain HTTP 429) actually
      // suppresses further requests on this Dio for 300s, rather than only
      // surfacing an error for the one call that hit it.
      PixivRateLimitSuppressionInterceptor(),
      // SEAM (S3): the auth interceptor (Authorization header + rotation on
      // 401, closing over this config's id — see FIX 6a-6e in
      // PLAN-SECURITY.md) is installed here. Do not add token refresh above
      // this line.
    ],
  );

  // FIX 7b: authenticated calls must not follow a redirect blind.
  dio.options.followRedirects = false;

  return dio;
});

/// Suppresses further requests on a Pixiv Dio for a back-off window after a
/// "Rate Limit" response, instead of merely letting that one call fail.
///
/// [SlidingWindowRateLimitInterceptor] paces requests but does not react to
/// what the server says about them — Pixiv's rate-limit signal can also
/// arrive as an `{"error": {"message": "Rate Limit ..."}}` body on an HTTP
/// 200, which a pure status-code check would miss entirely (see
/// `pixiv_client.dart`'s error-envelope handling).
class PixivRateLimitSuppressionInterceptor extends Interceptor {
  PixivRateLimitSuppressionInterceptor({
    this.backOff = const Duration(seconds: 300),
  });

  final Duration backOff;

  DateTime? _blockedUntil;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final blockedUntil = _blockedUntil;

    if (blockedUntil != null) {
      if (DateTime.now().isBefore(blockedUntil)) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'Pixiv rate limit active, retrying later',
          ),
        );
        return;
      }

      _blockedUntil = null;
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_looksRateLimited(response.data)) {
      _blockedUntil = DateTime.now().add(backOff);
    }

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (err.response?.statusCode == 429 ||
        _looksRateLimited(err.response?.data)) {
      _blockedUntil = DateTime.now().add(backOff);
    }

    handler.next(err);
  }

  static bool _looksRateLimited(dynamic data) {
    final decoded = switch (data) {
      final String s when s.isNotEmpty => _tryDecode(s),
      final Map<dynamic, dynamic> m => m,
      _ => null,
    };

    final message = switch (decoded) {
      final Map<dynamic, dynamic> m => switch (m['error']) {
        final Map<dynamic, dynamic> error =>
          (error['message'] ?? error['user_message'] ?? '').toString(),
        _ => '',
      },
      _ => '',
    };

    return message.toLowerCase().contains('rate limit');
  }

  static dynamic _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}
