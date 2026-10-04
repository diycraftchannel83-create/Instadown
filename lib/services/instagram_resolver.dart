import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/media_item.dart';

class InstagramResolver {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Mobile Safari/537.36';
  static const _appId = '936619743392459';
  static const _postDocId = '27128499623469141';

  final RegExp _image = RegExp(
    r'''<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)''',
    caseSensitive: false,
  );
  final RegExp _title = RegExp(
    r'''<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)''',
    caseSensitive: false,
  );

  Future<MediaItem> resolve(String input) async {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || !_isInstagramHost(uri.host)) {
      throw const FormatException('Masukkan URL Instagram HTTPS yang valid.');
    }

    final shortcode = _extractShortcode(uri);
    if (shortcode == null) {
      throw const FormatException(
        'URL harus berupa post, reel, atau video Instagram yang dapat dibagikan.',
      );
    }

    final client = http.Client();
    try {
      final landing =
          await _getWithRetry(client, Uri.https('www.instagram.com', '/'));
      final csrf = _csrfFromResponse(landing);
      final result = await _resolveGraphQl(client, shortcode, csrf);
      final item = _firstMediaItem(result);

      if (item == null) {
        throw Exception(
          'Instagram tidak mengembalikan media video untuk URL ini. '
          'Pastikan kontennya publik dan masih tersedia.',
        );
      }

      final videoUrl = _firstVideoUrl(item);
      if (videoUrl == null) {
        throw Exception(
          'URL Instagram ini bukan video publik yang dapat diambil.',
        );
      }

      return MediaItem(
        sourceUrl: value,
        mediaUrl: videoUrl,
        thumbnailUrl: _firstImageUrl(item) ?? _optional(_image, landing.body),
        title: _firstString(item, const ['caption', 'title']) ??
            _optional(_title, landing.body),
        author: _nestedString(item, const ['user', 'username']),
      );
    } on SocketException {
      throw Exception(
        'Koneksi ke Instagram gagal (Client socket failed). '
        'Periksa internet dan coba lagi.',
      );
    } on TimeoutException {
      throw Exception('Koneksi ke Instagram timeout. Silakan coba lagi.');
    } on http.ClientException catch (e) {
      throw Exception('Koneksi ke Instagram gagal: ${e.message}');
    } finally {
      client.close();
    }
  }

  bool _isInstagramHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'instagram.com' || lower.endsWith('.instagram.com');
  }

  String? _extractShortcode(Uri uri) {
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    for (var i = 0; i < segments.length - 1; i++) {
      final kind = segments[i].toLowerCase();
      if (kind == 'reel' || kind == 'reels' || kind == 'p' || kind == 'tv') {
        final code = segments[i + 1].trim();
        if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) return code;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _resolveGraphQl(
    http.Client client,
    String shortcode,
    String? csrf,
  ) async {
    final variables = jsonEncode({
      'shortcode': shortcode,
      '__relay_internal__pv__PolarisAIGMMediaWebLabelEnabledrelayprovider':
          false,
    });

    for (final endpoint in <Uri>[
      Uri.https('www.instagram.com', '/graphql/query'),
      Uri.https('www.instagram.com', '/api/graphql'),
    ]) {
      try {
        final response = await client
            .post(
              endpoint,
              headers: {
                'User-Agent': _userAgent,
                'Accept': 'application/json, text/plain, */*',
                'Content-Type': 'application/x-www-form-urlencoded',
                'X-IG-App-ID': _appId,
                if (csrf != null) 'X-CSRFToken': csrf,
                if (csrf != null) 'Cookie': 'csrftoken=$csrf',
                'Origin': 'https://www.instagram.com',
                'Referer': 'https://www.instagram.com/',
              },
              body: {
                'doc_id': _postDocId,
                'variables': variables,
              },
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> &&
              decoded['data'] is Map<String, dynamic>) {
            return decoded;
          }
          final message = _graphQlError(decoded);
          throw Exception(message);
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } on Exception {
        if (endpoint.path == '/api/graphql') {
          rethrow;
        }
      }
    }

    throw Exception('Instagram gagal memberikan metadata media publik. Coba lagi beberapa saat.');
  }

  Map<String, dynamic>? _firstMediaItem(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final webInfo = data['xdt_api__v1__media__shortcode__web_info'];
    if (webInfo is! Map<String, dynamic>) return null;
    final items = webInfo['items'];
    if (items is! List || items.isEmpty) return null;

    final first = items.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
    return null;
  }

  String? _firstVideoUrl(Map<String, dynamic> item) {
    final versions = item['video_versions'];
    if (versions is List) {
      for (final value in versions) {
        if (value is Map) {
          final url = value['url'];
          if (url is String && url.isNotEmpty) return _decode(url);
        }
      }
    }

    final carousel = item['carousel_media'];
    if (carousel is List) {
      for (final child in carousel) {
        if (child is Map) {
          final url = _firstVideoUrl(Map<String, dynamic>.from(child));
          if (url != null) return url;
        }
      }
    }
    return null;
  }

  String? _firstImageUrl(Map<String, dynamic> item) {
    final versions = item['image_versions2'];
    if (versions is Map) {
      final candidates = versions['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first;
        if (first is Map && first['url'] is String) {
          return _decode(first['url'] as String);
        }
      }
    }
    return null;
  }

  String? _firstString(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value is String && value.isNotEmpty) return _decode(value);
      if (value is Map && value['text'] is String) {
        return _decode(value['text'] as String);
      }
    }
    return null;
  }

  String? _nestedString(Map<String, dynamic> item, List<String> path) {
    dynamic current = item;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current is String && current.isNotEmpty ? current : null;
  }

  String? _csrfFromResponse(http.Response response) {
    final cookies = response.headers['set-cookie'];
    if (cookies == null) return null;
    final match = RegExp(r'(?:^|;\s*)csrftoken=([^;]+)').firstMatch(cookies);
    return match?.group(1);
  }

  Future<http.Response> _getWithRetry(http.Client client, Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await client
            .get(
              uri,
              headers: {
                'User-Agent': _userAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,'
                    'image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache',
                'Connection': 'close',
              },
            )
            .timeout(const Duration(seconds: 20));
      } on Object catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 700 * (attempt + 1)),
          );
        }
      }
    }

    if (lastError is SocketException) throw lastError;
    if (lastError is TimeoutException) throw lastError;
    if (lastError is http.ClientException) throw lastError;
    throw Exception('Gagal terhubung ke Instagram.');
  }

  String? _optional(RegExp pattern, String html) {
    final match = pattern.firstMatch(html);
    final value = match?.group(1);
    return value == null ? null : _decode(value);
  }

  String _decode(String value) => value
      .replaceAll(r'\/', '/')
      .replaceAll('&amp;', '&')
      .replaceAll('&#x2F;', '/')
      .replaceAll('&quot;', '"');

  String _graphQlError(dynamic decoded) {
    if (decoded is Map && decoded['errors'] is List) {
      final errors = decoded['errors'] as List;
      if (errors.isNotEmpty && errors.first is Map) {
        final message = errors.first['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
    return 'metadata tidak tersedia';
  }
}
