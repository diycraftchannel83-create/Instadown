import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/download_service.dart';
import '../services/instagram_resolver.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final controller = TextEditingController();
  final resolver = InstagramResolver();
  final downloader = DownloadService();
  MediaItem? item;
  bool loading = false;
  double progress = 0;
  String? error;

  Future<void> analyze() async {
    FocusScope.of(context).unfocus();
    setState(() { loading = true; error = null; item = null; });
    try {
      final result = await resolver.resolve(controller.text);
      if (mounted) setState(() => item = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> download() async {
    final media = item;
    if (media == null) return;
    setState(() => progress = 0);
    try {
      await downloader.download(media, onProgress: (value) {
        if (mounted) setState(() => progress = value);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video berhasil disimpan ke Galeri.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InstaDown', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Text(
            'Download video publik',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Tempel URL Instagram. Tidak perlu login.'),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://www.instagram.com/reel/...',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(icon: const Icon(Icons.clear_rounded), onPressed: controller.clear),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : analyze,
            icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search_rounded),
            label: Text(loading ? 'Menganalisis...' : 'Preview Media'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!))),
          ],
          if (item != null) ...[
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (item!.thumbnailUrl != null)
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        item!.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.video_library_rounded, size: 64),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item!.title ?? 'Instagram Video',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        if (progress > 0 && progress < 1) LinearProgressIndicator(value: progress),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: progress > 0 && progress < 1 ? null : download,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download Video'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Gunakan hanya untuk konten yang Anda miliki atau berhak menyimpannya. Konten private dan bypass login tidak didukung.'),
            ),
          ),
        ],
      ),
    );
  }
}
