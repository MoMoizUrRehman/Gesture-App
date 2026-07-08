import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'audio_service.dart';
import 'main.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  List<Map<String, dynamic>> songs = [];
  List<Map<String, dynamic>> filteredSongs = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchSongs();
    _searchController.addListener(_filterSongs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSongs() {
    final query = _searchController.text.toLowerCase();
    
    List<Map<String, dynamic>> newFilteredSongs;
    
    if (query.isEmpty) {
      newFilteredSongs = songs;
    } else {
      newFilteredSongs = songs.where((song) {
        final title = (song['title'] ?? '').toString().toLowerCase();
        final artist = (song['artist'] ?? '').toString().toLowerCase();
        return title.contains(query) || artist.contains(query);
      }).toList();
    }
    
    setState(() {
      filteredSongs = newFilteredSongs;
    });
  }

  Future<void> fetchSongs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('songs')
          .get();
      final data = snapshot.docs.map((doc) {
        final songData = doc.data();
        return {
          'id': doc.id,
          'title': songData['title'] ?? 'Unknown',
          'artist': songData['artist'] ?? 'Unknown',
          'url': songData['url'] ?? '',
          'image': songData['image'] ?? '',
        };
      }).toList();
      
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        songs = data;
        filteredSongs = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching songs: $e');
      
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        filteredSongs = [];
        isLoading = false;
      });
    }
  }

  void _showSongOptionsMenu(BuildContext context, Map<String, dynamic> song, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add, color: Colors.teal),
              title: const Text('Add to Album'),
              onTap: () {
                Navigator.pop(context);
                _showAddToAlbumDialog(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.teal),
              title: const Text('Add to Queue'),
              onTap: () {
                final audioService = AudioServiceProvider.of(context);
                audioService.addToQueue(
                  song['url']?.toString() ?? '',
                  song['title']?.toString() ?? 'Unknown Title',
                  song['artist']?.toString() ?? 'Unknown Artist',
                  song['image']?.toString(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${song['title']} added to queue')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToAlbumDialog(BuildContext context, Map<String, dynamic> song) {
    final albumsBox = Hive.box<Album>('albums');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Album'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: albumsBox.isEmpty
              ? const Center(child: Text('No albums available'))
              : ListView.builder(
                  itemCount: albumsBox.length,
                  itemBuilder: (context, index) {
                    final album = albumsBox.getAt(index);
                    if (album == null) return const SizedBox();
                    
                    return ListTile(
                      leading: const Icon(Icons.album, color: Colors.teal),
                      title: Text(album.name ?? 'Unnamed Album'),
                      subtitle: Text('${album.songIds?.length ?? 0} songs'),
                      onTap: () {
                        final songIds = album.songIds ?? [];
                        if (!songIds.contains(song['url']?.toString() ?? '')) {
                          songIds.add(song['url']?.toString() ?? '');
                          album.songIds = songIds;
                          album.save();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added to ${album.name}')),
                          );
                        } else {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Song already in album')),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Songs'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode ? Colors.grey[850] : Colors.teal[50],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.teal[300]! : Colors.teal[700]!,
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
          
          // Songs List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSongs.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : _buildSongList(filteredSongs, isDarkMode, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(
    List<Map<String, dynamic>> songs,
    bool isDarkMode,
    Color textColor,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: songs.length,
      itemBuilder: (context, index) => _buildSongCard(
        songs[index],
        index,
        isDarkMode,
        textColor,
      ),
    );
  }

  Widget _buildSongCard(
    Map<String, dynamic> song,
    int index,
    bool isDarkMode,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key('${song['url']}_$index'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.queue_music, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text(
                'Add to Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          final audioService = AudioServiceProvider.of(context);
          audioService.addToQueue(
            song['url']?.toString() ?? '',
            song['title']?.toString() ?? 'Unknown Title',
            song['artist']?.toString() ?? 'Unknown Artist',
            song['image']?.toString(),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${song['title']} added to queue')),
          );
          return false;
        },
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: isDarkMode ? Colors.grey[850] : Colors.teal[200],
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Hero(
              tag: 'song_${song['title']}_$index',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  song['image']?.toString() ?? 'assets/images/bayaan.jpg',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDarkMode
                              ? [Colors.grey[800]!, Colors.grey[700]!]
                              : [Colors.teal[100]!, Colors.teal[200]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),
            title: Text(
              song['title']?.toString() ?? 'Unknown Title',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                song['artist']?.toString() ?? 'Unknown Artist',
                style: TextStyle(
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.grey[800] : Colors.grey[200])
                    ?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  size: 22,
                ),
                onPressed: () {
                  _showSongOptionsMenu(context, song, isDarkMode);
                },
              ),
            ),
            onTap: () async {
              final url = song['url']?.toString() ?? '';
              if (url.isNotEmpty) {
                try {
                  final audioService = AudioServiceProvider.of(context);
                  await audioService.playSong(
                    url: url,
                    title: song['title']?.toString() ?? 'Unknown Title',
                    artist: song['artist']?.toString() ?? 'Unknown Artist',
                    image: song['image']?.toString(),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Now playing: ${song['title']}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error playing song: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error playing song: $e'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Song URL not available'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No songs available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add songs to your Firebase collection',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
