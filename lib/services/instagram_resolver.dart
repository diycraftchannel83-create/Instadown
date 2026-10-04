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

  Future<MediaItem> resolve(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !(uri.host == 'instagram.com' || uri.host == 'www.instagram.com')) {
      throw const FormatException('Masukkan URL Instagram yang valid.');
    }
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw Exception('Instagram mengembalikan HTTP ${response.statusCode}.');
    }
    final video = _get(_video, response.body);
    if (video == null) {
      throw Exception('Video publik tidak ditemukan. Konten private atau halaman yang dibatasi tidak didukung.');
    }
    return MediaItem(
      sourceUrl: input.trim(),
      mediaUrl: _decode(video),
      thumbnailUrl: _optional(_image, response.body),
      title: _optional(_title, response.body),
    );
  }

  String? _get(RegExp pattern, String html) => pattern.firstMatch(html)?.group(1);
  String? _optional(RegExp pattern, String html) {
    final value = _get(pattern, html);
    return value == null ? null : _decode(value);
  }
  String _decode(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&#x2F;', '/')
      .replaceAll('&quot;', '"');
}
