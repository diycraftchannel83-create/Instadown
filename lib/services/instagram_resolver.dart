import 'package:http/http.dart' as http;
import '../models/media_item.dart';
class InstagramResolver{
 final _video=RegExp(r'<meta[^>]+property=["\']og:video(?::secure_url)?["\'][^>]+content=["\']([^"\']+)',caseSensitive:false);
 final _image=RegExp(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)',caseSensitive:false);
 final _title=RegExp(r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)',caseSensitive:false);
 Future<MediaItem> resolve(String input)async{
  final uri=Uri.tryParse(input.trim());
  if(uri==null||!(uri.host=='instagram.com'||uri.host=='www.instagram.com'))throw const FormatException('Masukkan URL Instagram yang valid.');
  final r=await http.get(uri,headers:{'User-Agent':'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36','Accept-Language':'en-US,en;q=0.9'}).timeout(const Duration(seconds:20));
  if(r.statusCode<200||r.statusCode>=400)throw Exception('Instagram mengembalikan HTTP ${r.statusCode}.');
  final v=_get(_video,r.body);if(v==null)throw Exception('Video publik tidak ditemukan. Konten private atau halaman yang dibatasi tidak didukung.');
  return MediaItem(sourceUrl:input.trim(),mediaUrl:_decode(v),thumbnailUrl:_opt(_image,r.body),title:_opt(_title,r.body));
 }
 String? _get(RegExp p,String s)=>p.firstMatch(s)?.group(1);
 String? _opt(RegExp p,String s){final x=_get(p,s);return x==null?null:_decode(x);}
 String _decode(String s)=>s.replaceAll('&amp;','&').replaceAll('&#x2F;','/').replaceAll('&quot;','"');
}
