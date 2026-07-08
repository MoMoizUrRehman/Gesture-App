import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// A service that manages the audio player across the entire app.
/// This ensures the audio continues playing even when navigating between screens.
class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  String? _currentSongTitle;
  String? _currentSongArtist;
  String? _currentSongImage;
  String? _currentSongUrl;

  String? get currentSongTitle => _currentSongTitle;
  String? get currentSongArtist => _currentSongArtist;
  String? get currentSongImage => _currentSongImage;
  String? get currentSongUrl => _currentSongUrl;

  bool get isPlaying => _player.playing;

  // Queue management
  final List<Map<String, String>> _queue = [];
  List<Map<String, String>> get queue => List.unmodifiable(_queue);

  // Recently played tracking
  final List<Map<String, String>> _recentlyPlayed = [];
  List<Map<String, String>> get recentlyPlayed => List.unmodifiable(_recentlyPlayed);

  // Add song to queue
  void addToQueue(String url, String title, String artist, String? image) {
    _queue.add({
      'url': url,
      'title': title,
      'artist': artist,
      'image': image ?? '',
    });
    notifyListeners();
  }

  // Remove from queue
  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      notifyListeners();
    }
  }

  // Clear queue
  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  // Play next from queue
  Future<void> playNext() async {
    if (_queue.isNotEmpty) {
      final nextSong = _queue.removeAt(0);
      await playSong(
        url: nextSong['url']!,
        title: nextSong['title']!,
        artist: nextSong['artist']!,
        image: nextSong['image'],
      );
    }
  }

  // Add to recently played
  void _addToRecentlyPlayed(String url, String title, String artist, String? image) {
    // Remove if already exists
    _recentlyPlayed.removeWhere((song) => song['url'] == url);
    
    // Add to beginning
    _recentlyPlayed.insert(0, {
      'url': url,
      'title': title,
      'artist': artist,
      'image': image ?? '',
    });
    
    // Keep only last 20
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed.removeLast();
    }
  }

  /// Play a song from a URL
  Future<void> playSong({
    required String url,
    required String title,
    required String artist,
    String? image,
  }) async {
    try {
      // Stop any currently playing song first
      if (_player.playing) {
        await _player.stop();
      }
      
      // Update song info immediately and notify listeners
      _currentSongTitle = title;
      _currentSongArtist = artist;
      _currentSongImage = image;
      _currentSongUrl = url;
      
      // Add to recently played
      _addToRecentlyPlayed(url, title, artist, image);
      
      // Notify listeners immediately so UI updates
      notifyListeners();
      
      // Then load and play the audio
      await _player.setUrl(url);
      await _player.play();
      
      // Notify again after playback starts
      notifyListeners();
    } catch (e) {
      print('Error playing song: $e');
      rethrow;
    }
  }

  /// Pause the current song
  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.play();
    notifyListeners();
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    _currentSongTitle = null;
    _currentSongArtist = null;
    _currentSongImage = null;
    _currentSongUrl = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

/// InheritedWidget to provide AudioService throughout the widget tree
class AudioServiceProvider extends InheritedNotifier<AudioService> {
  final AudioService audioService;

  const AudioServiceProvider({
    super.key,
    required this.audioService,
    required super.child,
  }) : super(notifier: audioService);

  static AudioService of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<AudioServiceProvider>();
    if (provider == null) {
      throw Exception('AudioServiceProvider not found in widget tree');
    }
    return provider.audioService;
  }

  static AudioService? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AudioServiceProvider>()
        ?.audioService;
  }
}
