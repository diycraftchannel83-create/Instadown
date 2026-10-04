import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/media_item.dart';

class InstagramResolver {
  final RegExp _video = RegExp(
    r'''<meta[^>]+property=["']og:video(?::secure_url)?["'][^>]+content=["']([^"']+)''',
    caseSensitive: false,
  );
  final RegExp _image = RegExp(
    r'''<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)''',
    caseSensitive: false,
  );
  final RegExp _title = RegExp(
    r'''<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)''',
    caseSensitive: false,
  );

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Mobile Safari/537.36';

  Future<MediaItem> resolve(String input) async {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'instagram.com' || uri.host == 'www.instagram.com')) {
      throw const FormatException(
        'Masukkan URL Instagram HTTPS yang valid.',
      );
    }

    final client = http.Client();
    try {
      final response = await _getWithRetry(client, uri);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw Exception(
          'Instagram mengembalikan HTTP ${response.statusCode}. '
          'Coba lagi beberapa saat.',
        );
      }

      final html = response.body;
      final video = _firstNonEmpty([
        _get(_video, html),
        _findJsonVideo(html),
      ]);

      if (video == null) {
        if (_looksRestricted(html)) {
          throw Exception(
            'Instagram membatasi halaman ini. '
            'InstaDown hanya mendukung konten publik tanpa login.',
          );
        }
        throw Exception(
          'URL tidak menyediakan video publik yang dapat diambil. '
          'Pastikan URL Reel/video bersifat publik.',
        );
      }

      return MediaItem(
        sourceUrl: value,
        mediaUrl: _decode(video),
        thumbnailUrl: _optional(_image, html),
        title: _optional(_title, html),
      );
    } on SocketException {
      throw Exception(
        'Koneksi ke Instagram gagal (Client socket failed). '
        'Periksa internet dan coba lagi.',
      );
    } on TimeoutException {
      throw Exception(
        'Koneksi ke Instagram timeout. Silakan coba lagi.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Koneksi ke Instagram gagal: ${e.message}',
      );
    } finally {
      client.close();
    }
  }

  Future<http.Response> _getWithRetry(
    http.Client client,
    Uri uri,
  ) async {
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

    if (lastError is SocketException) {
      throw lastError!;
    }
    if (lastError is TimeoutException) {
      throw lastError!;
    }
    if (lastError is http.ClientException) {
      throw lastError!;
    }
    throw Exception('Gagal terhubung ke Instagram.');
  }

  String? _get(RegExp pattern, String html) =>
      pattern.firstMatch(html)?.group(1);

  String? _optional(RegExp pattern, String html) {
    final value = _get(pattern, html);
    return value == null ? null : _decode(value);
  }

  String? _findJsonVideo(String html) {
    final patterns = <RegExp>[
      RegExp(r'["\\']video_url["\\']\s*:\s*["\\']([^"\\']+)'),
      RegExp(r'["\\']video_versions["\\']\s*:\s*\[\s*\{[^}]*["\\']url["\\']\s*:\s*["\\']([^"\\']+)'),
    ];
    for (final pattern in patterns) {
      final value = _get(pattern, html);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool _looksRestricted(String html) {
    final lower = html.toLowerCase();
    return lower.contains('login') &&
        (lower.contains('log in') ||
            lower.contains('login instagram') ||
            lower.contains('accounts/login'));
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _decode(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&#x2F;', '/')
      .replaceAll('&quot;', '"')
      .replaceAll(r'\\/', '/');
}
