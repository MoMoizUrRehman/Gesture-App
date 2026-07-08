import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'main.dart'; // import your Hive Song model

Future<String?> downloadSongs({
  required String url,
  required String title,
  required String artist,
  String? image,
}) async {
  try {
    print("=== Starting download for: $title ===");
    print("URL: $url");
    
    final box = Hive.box<Song>('downloads');
    print("Hive box opened: ${box.isOpen}");
    print("Current downloads count: ${box.length}");

    var uuid = const Uuid();
    String id = uuid.v4();

    // Check for duplicates
    if (box.values.any((song) => song.title == title && song.artist == artist)) {
      print("Song already downloaded!");
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    print("App directory: ${dir.path}");
    
    final songDir = Directory('${dir.path}/songs');

    if (!await songDir.exists()) {
      print("Creating songs directory...");
      await songDir.create(recursive: true);
    }

    // Clean filename to avoid issues
    final cleanTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final filepath = '${songDir.path}/$cleanTitle.mp3';
    print("Download path: $filepath");

    // Download the file with progress
    print("Starting download from: $url");
    
    final dio = Dio();
    dio.options.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    dio.options.followRedirects = true;
    dio.options.maxRedirects = 5;
    dio.options.validateStatus = (status) => status! < 500;
    
    await dio.download(
      url,
      filepath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = (received / total * 100).toStringAsFixed(0);
          print('Downloading $title: $progress%');
        } else {
          print('Downloading $title: ${received} bytes received');
        }
      },
    );
    
    print("Download completed!");
    
    // Check if file exists
    final file = File(filepath);
    if (!await file.exists()) {
      print("ERROR: Downloaded file not found!");
      return null;
    }
    
    final fileSize = await file.length();
    print("File size: ${fileSize} bytes");
    
    if (fileSize == 0) {
      print("ERROR: Downloaded file is empty!");
      await file.delete();
      return null;
    }

    // Create and save song to Hive
    final song = Song(
      artist: artist,
      image: image,
      title: title,
      path: filepath,
      id: id,
    );
    
    print("Saving to Hive with ID: $id");
    await box.put(id, song);
    await box.flush(); // Force write to disk
    
    print("Saved! Total downloads now: ${box.length}");
    print("=== Download complete for: $title ===");
    
    return filepath;
  } catch (e, stackTrace) {
    print("=== Download failed for: $title ===");
    print("Error: $e");
    print("Stack trace: $stackTrace");
    return null;
  }
}
