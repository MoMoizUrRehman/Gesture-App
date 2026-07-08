import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'audio_service.dart';

/// A mini player widget that shows the currently playing song
/// and provides basic playback controls. Tapping it opens a full-screen player.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  Color _dominantColor = Colors.teal;
  Color _vibrantColor = Colors.teal;
  String? _lastProcessedImage;

  Future<void> _updatePaletteGenerator(String? imageUrl) async {
    // Skip if no image or same image
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == _lastProcessedImage) {
      return;
    }

    try {
      _lastProcessedImage = imageUrl;
      
      // Determine if it's a network image or asset image
      final ImageProvider imageProvider;
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        imageProvider = NetworkImage(imageUrl);
      } else {
        imageProvider = AssetImage(imageUrl);
      }
      
      final PaletteGenerator paletteGenerator = 
          await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100),
        maximumColorCount: 10,
      );

      if (mounted) {
        setState(() {
          _dominantColor = paletteGenerator.dominantColor?.color ?? Colors.teal;
          _vibrantColor = paletteGenerator.vibrantColor?.color ?? 
                         paletteGenerator.darkVibrantColor?.color ?? 
                         Colors.teal;
        });
      }
    } catch (e) {
      print('Error generating palette: $e');
      if (mounted) {
        setState(() {
          _dominantColor = Colors.teal;
          _vibrantColor = Colors.teal;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder to listen to AudioService changes
    return AnimatedBuilder(
      animation: AudioServiceProvider.of(context),
      builder: (context, child) {
        final audioService = AudioServiceProvider.of(context);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        // Only show the mini player if a song is loaded
        if (audioService.currentSongTitle == null) {
          return const SizedBox.shrink();
        }

        // Update palette when image changes
        if (audioService.currentSongImage != _lastProcessedImage) {
          _updatePaletteGenerator(audioService.currentSongImage);
        }

        return Dismissible(
          key: const Key('mini_player'),
          direction: DismissDirection.down,
          onDismissed: (direction) {
            audioService.stop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Playback stopped'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullScreenPlayer(
                    initialDominantColor: _dominantColor,
                    initialVibrantColor: _vibrantColor,
                  ),
                ),
              );
            },
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _dominantColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                    _vibrantColor.withOpacity(isDarkMode ? 0.2 : 0.15),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _dominantColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Album art
                    Hero(
                      tag: 'album_art',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: audioService.currentSongImage != null && audioService.currentSongImage!.isNotEmpty
                            ? _buildImage(
                                audioService.currentSongImage!,
                                width: 54,
                                height: 54,
                                isDarkMode: isDarkMode,
                              )
                            : _buildPlaceholder(isDarkMode),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Song info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audioService.currentSongTitle ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            audioService.currentSongArtist ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Playback controls
                    StreamBuilder<bool>(
                      stream: audioService.player.playingStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (isPlaying) {
                              await audioService.pause();
                            } else {
                              await audioService.resume();
                            }
                          },
                          color: Colors.teal,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(bool isDarkMode) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey[800]!, Colors.grey[900]!]
              : [Colors.grey[300]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.music_note,
        color: Colors.white70,
        size: 28,
      ),
    );
  }

  // Helper method to build image based on URL type (asset vs network)
  Widget _buildImage(String imageUrl, {double? width, double? height, required bool isDarkMode}) {
    final bool isNetworkImage = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(isDarkMode);
        },
      );
    } else {
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(isDarkMode);
        },
      );
    }
  }
}

/// Full-screen player widget
class FullScreenPlayer extends StatefulWidget {
  final Color? initialDominantColor;
  final Color? initialVibrantColor;
  
  const FullScreenPlayer({
    super.key,
    this.initialDominantColor,
    this.initialVibrantColor,
  });

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  bool _isShuffleEnabled = false;
  bool _isLooping = false;
  late Color _dominantColor;
  late Color _vibrantColor;
  String? _lastProcessedImage;

  @override
  void initState() {
    super.initState();
    // Use initial colors from MiniPlayer if available, otherwise use default
    _dominantColor = widget.initialDominantColor ?? Colors.teal;
    _vibrantColor = widget.initialVibrantColor ?? Colors.teal;
    
    // Extract colors when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioService = AudioServiceProvider.of(context);
      if (audioService.currentSongImage != null) {
        _updatePaletteGenerator(audioService.currentSongImage);
      }
    });
  }

  Future<void> _updatePaletteGenerator(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == _lastProcessedImage) {
      return;
    }

    try {
      _lastProcessedImage = imageUrl;
      
      // Determine if it's a network image or asset image
      final ImageProvider imageProvider;
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        imageProvider = NetworkImage(imageUrl);
      } else {
        imageProvider = AssetImage(imageUrl);
      }
      
      final PaletteGenerator paletteGenerator = 
          await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 20,
      );

      if (mounted) {
        setState(() {
          _dominantColor = paletteGenerator.dominantColor?.color ?? Colors.teal;
          _vibrantColor = paletteGenerator.vibrantColor?.color ?? 
                         paletteGenerator.darkVibrantColor?.color ?? 
                         Colors.teal;
        });
      }
    } catch (e) {
      print('Error generating palette: $e');
      if (mounted) {
        setState(() {
          _dominantColor = Colors.teal;
          _vibrantColor = Colors.teal;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioService = AudioServiceProvider.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Update palette if image changes
    if (audioService.currentSongImage != _lastProcessedImage) {
      _updatePaletteGenerator(audioService.currentSongImage);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _dominantColor.withOpacity(isDarkMode ? 0.4 : 0.3),
              _vibrantColor.withOpacity(isDarkMode ? 0.3 : 0.2),
              (isDarkMode ? Colors.black : Colors.white).withOpacity(0.95),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Now Playing',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music),
                    onPressed: () {
                      _showQueueDialog(context, audioService);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Album Art
            Hero(
              tag: 'album_art',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: audioService.currentSongImage != null && audioService.currentSongImage!.isNotEmpty
                    ? _buildLargeImage(
                        audioService.currentSongImage!,
                        isDarkMode: isDarkMode,
                      )
                    : Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDarkMode
                                ? [Colors.grey[800]!, Colors.grey[900]!]
                                : [Colors.grey[300]!, Colors.grey[400]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.music_note, size: 100, color: Colors.white70),
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Song Title & Artist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    audioService.currentSongTitle ?? 'Unknown',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    audioService.currentSongArtist ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Progress bar
            StreamBuilder<Duration?>(
              stream: audioService.player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = audioService.player.duration ?? Duration.zero;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Slider(
                      value: position.inMilliseconds.toDouble(),
                      max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                      activeColor: Colors.teal,
                      inactiveColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      onChanged: (value) {
                        audioService.player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ],
                );
              },
            ),

            // Playback controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: _isShuffleEnabled ? Colors.teal : (isDarkMode ? Colors.white54 : Colors.black54),
                    ),
                    onPressed: () {
                      setState(() => _isShuffleEnabled = !_isShuffleEnabled);
                    },
                  ),

                  // Previous (Play from queue if available)
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 40),
                    onPressed: audioService.queue.isNotEmpty
                        ? () => audioService.playNext()
                        : null,
                    color: Colors.teal,
                  ),

                  // Play/Pause
                  StreamBuilder<bool>(
                    stream: audioService.player.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 40,
                          ),
                          color: Colors.white,
                          onPressed: () async {
                            if (isPlaying) {
                              await audioService.pause();
                            } else {
                              await audioService.resume();
                            }
                          },
                        ),
                      );
                    },
                  ),

                  // Next (Play next from queue)
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 40),
                    onPressed: audioService.queue.isNotEmpty
                        ? () => audioService.playNext()
                        : null,
                    color: Colors.teal,
                  ),

                  // Loop
                  IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: _isLooping ? Colors.teal : (isDarkMode ? Colors.white54 : Colors.black54),
                    ),
                    onPressed: () {
                      setState(() => _isLooping = !_isLooping);
                      audioService.player.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Volume & Speed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Volume
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.volume_down, color: Colors.teal),
                        Expanded(
                          child: StreamBuilder<double>(
                            stream: audioService.player.volumeStream,
                            builder: (context, snapshot) {
                              final volume = snapshot.data ?? 1.0;
                              return Slider(
                                value: volume,
                                min: 0.0,
                                max: 1.0,
                                activeColor: Colors.teal,
                                inactiveColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                onChanged: (value) {
                                  audioService.player.setVolume(value);
                                },
                              );
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up, color: Colors.teal),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Speed
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.speed, color: Colors.teal),
                    onSelected: (speed) {
                      audioService.player.setSpeed(speed);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                      const PopupMenuItem(value: 0.75, child: Text('0.75x')),
                      const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                      const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),  // Column
          ),  // ConstrainedBox
        ),  // SingleChildScrollView
      ),  // SafeArea
      ),  // Container
    );  // Scaffold
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showQueueDialog(BuildContext context, AudioService audioService) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Queue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (audioService.queue.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      audioService.clearQueue();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const Divider(),
            Expanded(
              child: audioService.queue.isEmpty
                  ? const Center(
                      child: Text('Queue is empty'),
                    )
                  : ListView.builder(
                      itemCount: audioService.queue.length,
                      itemBuilder: (context, index) {
                        final song = audioService.queue[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: song['image'] != null && song['image']!.isNotEmpty
                                ? NetworkImage(song['image']!)
                                : null,
                            child: song['image'] == null || song['image']!.isEmpty
                                ? const Icon(Icons.music_note)
                                : null,
                          ),
                          title: Text(song['title'] ?? 'Unknown'),
                          subtitle: Text(song['artist'] ?? 'Unknown'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              audioService.removeFromQueue(index);
                              if (audioService.queue.isEmpty) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          onTap: () {
                            audioService.playSong(
                              url: song['url']!,
                              title: song['title']!,
                              artist: song['artist']!,
                              image: song['image'],
                            );
                            audioService.removeFromQueue(index);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build large album art image based on URL type (asset vs network)
  Widget _buildLargeImage(String imageUrl, {required bool isDarkMode}) {
    final bool isNetworkImage = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    
    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        width: 320,
        height: 320,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildLargePlaceholder(isDarkMode);
        },
      );
    } else {
      return Image.asset(
        imageUrl,
        width: 320,
        height: 320,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildLargePlaceholder(isDarkMode);
        },
      );
    }
  }

  Widget _buildLargePlaceholder(bool isDarkMode) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey[800]!, Colors.grey[900]!]
              : [Colors.grey[300]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.music_note, size: 100, color: Colors.white70),
    );
  }
}
