import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
class DownloadRecord{final String id,title,sourceUrl;final String? localUri;final DateTime createdAt;const DownloadRecord({required this.id,required this.title,required this.sourceUrl,required this.localUri,required this.createdAt});Map<String,dynamic> toJson()=>{'id':id,'title':title,'sourceUrl':sourceUrl,'localUri':localUri,'createdAt':createdAt.toIso8601String()};factory DownloadRecord.fromJson(Map<String,dynamic> j)=>DownloadRecord(id:j['id'],title:j['title'],sourceUrl:j['sourceUrl'],localUri:j['localUri'],createdAt:DateTime.parse(j['createdAt']));}
class DownloadService{
 static const _channel=MethodChannel('instadown/media_store');static const _key='download_history';
 Future<String?> download(MediaItem item,{void Function(double)? onProgress})async{
  final r=await http.Request('GET',Uri.parse(item.mediaUrl)).send();if(r.statusCode!=200)throw Exception('Download gagal: HTTP ${r.statusCode}.');
  final total=r.contentLength??0;final bytes=<int>[];var received=0;await for(final c in r.stream){bytes.addAll(c);received+=c.length;if(total>0)onProgress?.call(received/total);}
  final name='Instagram_${DateTime.now().millisecondsSinceEpoch}.mp4';final uri=await _channel.invokeMethod<String>('saveVideo',{'name':name,'bytes':base64Encode(bytes)});
  final p=await SharedPreferences.getInstance();final records=await history();records.insert(0,DownloadRecord(id:DateTime.now().microsecondsSinceEpoch.toString(),title:item.title??name,sourceUrl:item.sourceUrl,localUri:uri,createdAt:DateTime.now()));await p.setString(_key,jsonEncode(records.map((e)=>e.toJson()).toList()));return uri;
 }
 Future<List<DownloadRecord>> history()async{final p=await SharedPreferences.getInstance();final raw=p.getString(_key);if(raw==null)return[];return(jsonDecode(raw)as List).map((e)=>DownloadRecord.fromJson(Map<String,dynamic>.from(e))).toList();}
 Future<void> clearHistory()async{final p=await SharedPreferences.getInstance();await p.remove(_key);}
}
