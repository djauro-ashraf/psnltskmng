import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:personaltskmng/quran_data/data/pack_codec.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

/// Gets the bytes at [url]. The app uses [HttpFetcher]; tests give a fake.
typedef Fetch = Future<List<int>> Function(Uri url);

/// Plain HTTP GET (redirects followed: a GitHub release redirects to its
/// file host).
class HttpFetcher {
  HttpFetcher() : _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);

  final HttpClient _client;

  Future<List<int>> call(Uri url) async {
    final request = await _client.getUrl(url);
    request.headers.set(HttpHeaders.userAgentHeader, 'psnltskmng/1.0');
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  void close() => _client.close(force: true);
}

/// Lets a running download be stopped.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// The download was cancelled by the reader.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// The download failed for good (after the retries).
class PackInstallException implements Exception {
  const PackInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a pack into the Quran folder, checks it, and marks it installed.
///
/// The font pack (604 files) is fetched four at a time and can be run again
/// after it stopped: files already there are kept. Every file is checked before
/// it is kept (a font must be a font, a pack must have all its lines), and a
/// failed file is retried.
class PackInstaller {
  PackInstaller({
    required this.storage,
    required this.fetch,
    this.retries = 3,
    this.workers = 4,
    this.retryDelay = const Duration(seconds: 2),
  });

  final DirectoryPackStorage storage;
  final Fetch fetch;
  final int retries;
  final int workers;
  final Duration retryDelay;

  /// [onProgress] gets the part done, 0 to 1. Throws [DownloadCancelled] or
  /// [PackInstallException].
  Future<void> install(
    QuranPack pack, {
    void Function(double fraction)? onProgress,
    CancelToken? cancel,
  }) async {
    final files = pack.files;
    var done = 0;
    var next = 0;
    var failed = false;
    onProgress?.call(0);

    Future<void> worker() async {
      while (true) {
        if (failed) return;
        if (cancel?.isCancelled ?? false) throw const DownloadCancelled();
        final index = next++;
        if (index >= files.length) return;
        try {
          await _installFile(pack, files[index], cancel);
        } catch (_) {
          failed = true;
          rethrow;
        }
        done++;
        onProgress?.call(done / files.length);
      }
    }

    final count = pack.kind == QuranPackKind.fonts ? workers : 1;
    await Future.wait([for (var i = 0; i < count; i++) worker()]);
    await storage.writeMeta(pack);
  }

  Future<void> _installFile(
    QuranPack pack,
    PackFile file,
    CancelToken? cancel,
  ) async {
    if (pack.kind == QuranPackKind.fonts && storage.has(file.path)) return;
    Object? last;
    for (var attempt = 1; attempt <= retries; attempt++) {
      if (cancel?.isCancelled ?? false) throw const DownloadCancelled();
      try {
        final bytes = await fetch(file.url);
        final problem = _problem(pack.kind, bytes);
        if (problem != null) throw FormatException(problem);
        await storage.write(file.path, bytes);
        return;
      } catch (error) {
        last = error;
        if (attempt < retries) await Future<void>.delayed(retryDelay * attempt);
      }
    }
    throw PackInstallException('${pack.title}: ${file.path}: $last');
  }

  static String? _problem(QuranPackKind kind, List<int> bytes) {
    switch (kind) {
      case QuranPackKind.fonts:
      case QuranPackKind.textFont:
        return looksLikeFont(bytes) ? null : 'not a font file';
      case QuranPackKind.layout:
        return PackCodec.problem(bytes, shape: PackCodec.pagesShape);
      case QuranPackKind.words:
      case QuranPackKind.translation:
        return PackCodec.problem(bytes, shape: PackCodec.surahsShape);
    }
  }

  /// TrueType (0x00010000 or "true") or OpenType ("OTTO"), and not a tiny
  /// error page.
  static bool looksLikeFont(List<int> b) {
    if (b.length < 1000) return false;
    final tag = String.fromCharCodes(b.sublist(0, 4));
    return (b[0] == 0 && b[1] == 1 && b[2] == 0 && b[3] == 0) ||
        tag == 'true' ||
        tag == 'OTTO';
  }
}
