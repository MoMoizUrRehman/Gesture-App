import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'audio_service.dart';
import 'downloads.dart';
import 'main.dart';
import 'album_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const HomeScreen({super.key, this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> songs = [];
  List<Map<String, dynamic>> filteredSongs = [];
  List<Map<String, dynamic>> filteredPlaylists = [];
  List<Map<String, dynamic>> todaysRecommendations = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    fetchSongs();
    _searchController.addListener(_filterSongsAndPlaylists);
    
    // Auto-hide app bar on scroll
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && _showAppBar) {
        setState(() => _showAppBar = false);
      } else if (_scrollController.offset <= 50 && !_showAppBar) {
        setState(() => _showAppBar = true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generateTodaysRecommendations() {
    if (songs.isEmpty) {
      todaysRecommendations = [];
      return;
    }
    
    final random = Random();
    final List<Map<String, dynamic>> recommendations = [];
    final List<int> usedIndices = [];
    
    // Get up to 5 random songs
    final count = songs.length < 5 ? songs.length : 5;
    
    while (recommendations.length < count) {
      final randomIndex = random.nextInt(songs.length);
      if (!usedIndices.contains(randomIndex)) {
        usedIndices.add(randomIndex);
        recommendations.add(songs[randomIndex]);
      }
    }
    
    setState(() {
      todaysRecommendations = recommendations;
    });
  }

  void _filterSongsAndPlaylists() {
    final query = _searchController.text.toLowerCase();
    
    // Do the filtering OUTSIDE of setState to avoid rebuild issues
    List<Map<String, dynamic>> newFilteredSongs;
    List<Map<String, dynamic>> newFilteredPlaylists = [];
    
    if (query.isEmpty) {
      newFilteredSongs = songs;
    } else {
      // Filter songs
      newFilteredSongs = songs.where((song) {
        final title = (song['title'] ?? '').toString().toLowerCase();
        final artist = (song['artist'] ?? '').toString().toLowerCase();
        return title.contains(query) || artist.contains(query);
      }).toList();
      
      // Filter playlists from Hive
      final albumsBox = Hive.box<Album>('albums');
      final currentUser = FirebaseAuth.instance.currentUser;
      
      for (int i = 0; i < albumsBox.length; i++) {
        final album = albumsBox.getAt(i);
        if (album != null) {
          // Include if it matches search and is either:
          // 1. User's own playlist, or
          // 2. A public playlist
          final albumName = (album.name ?? '').toLowerCase();
          final creatorName = (album.createdByName ?? '').toLowerCase();
          
          if ((albumName.contains(query) || creatorName.contains(query)) &&
              (album.userId == currentUser?.uid || album.isPublic == true)) {
            newFilteredPlaylists.add({
              'name': album.name ?? 'Unnamed Playlist',
              'image': album.coverImage,
              'songCount': album.songIds?.length ?? 0,
              'albumIndex': i,
              'album': album,
              'createdBy': album.createdByName ?? 'Unknown',
              'isPublic': album.isPublic ?? false,
            });
          }
        }
      }
    }
    
    // Now update the state with the filtered results
    setState(() {
      filteredSongs = newFilteredSongs;
      filteredPlaylists = newFilteredPlaylists;
    });
  }

  Future<void> fetchSongs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('songs')
          .get();
      print('Fetched ${snapshot.docs.length} songs');
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
      
      // Debug: Print song URLs
      for (var song in data) {
        print('Song: ${song['title']}, URL: ${song['url']}, Type: ${song['url']?.runtimeType}');
      }

      if (!mounted) return; // Check if widget is still mounted

      setState(() {
        songs = data;
        filteredSongs = data;
        isLoading = false;
      });
      
      // Generate Today's Recommendations after fetching songs
      _generateTodaysRecommendations();
    } catch (e) {
      print('Error fetching songs: $e');
      
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        filteredSongs = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final audioService = AudioServiceProvider.of(context);

    // Get both name and email from userData
    final userName = widget.userData?['name'] ?? 'User';
    final userEmail = widget.userData?['email'] ?? '';

    // Get user albums from Hive
    final albumsBox = Hive.box<Album>('albums');
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<Map<String, dynamic>> userAlbums = [];
    
    if (currentUser != null) {
      for (int i = 0; i < albumsBox.length; i++) {
        final album = albumsBox.getAt(i);
        if (album != null && album.userId == currentUser.uid) {
          // Get album cover (first song's image or custom cover)
          String? coverImage = album.coverImage;
          if (coverImage == null || coverImage.isEmpty) {
            // Try to get first song's image
            if (album.songIds != null && album.songIds!.isNotEmpty) {
              final firstSongId = album.songIds!.first;
              final songDoc = songs.firstWhere(
                (s) => s['id'] == firstSongId,
                orElse: () => {},
              );
              coverImage = songDoc['image'] as String?;
            }
          }
          
          userAlbums.add({
            'name': album.name ?? 'Unnamed Album',
            'image': coverImage,
            'songCount': album.songIds?.length ?? 0,
            'albumIndex': i,
            'album': album,
          });
        }
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== TOP HEADER ====================
            _buildHeader(isDarkMode, userName, userEmail),

            const SizedBox(height: 12),

            // ==================== SEARCH BAR ====================
            _buildSearchBar(isDarkMode, textColor),

            const SizedBox(height: 24),

            // ==================== SEARCH RESULTS FOR PLAYLISTS ====================
            if (_searchController.text.isNotEmpty && filteredPlaylists.isNotEmpty) ...[
              _buildSectionHeader('Playlists', textColor),
              const SizedBox(height: 12),
              _buildAlbumsSection(filteredPlaylists, isDarkMode),
              const SizedBox(height: 28),
            ],

            // ==================== MY ALBUMS ====================
            if (_searchController.text.isEmpty) ...[
              _buildSectionHeader('My Albums', textColor),
              const SizedBox(height: 12),
              _buildAlbumsSection(userAlbums, isDarkMode),
              const SizedBox(height: 28),
            ],

            // ==================== PUBLIC PLAYLISTS ====================
            if (_searchController.text.isEmpty) ...[
              _buildSectionHeader('Public Playlists', textColor),
              const SizedBox(height: 12),
              _buildPublicPlaylistsSection(isDarkMode, textColor),
              const SizedBox(height: 28),
            ],

            // ==================== TODAY'S RECOMMENDATIONS ====================
            if (_searchController.text.isEmpty) ...[
              _buildSectionHeader('Today\'s Recommendations', textColor),
              const SizedBox(height: 12),
              isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : todaysRecommendations.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _buildSongList(
                      todaysRecommendations
                          .map(
                            (song) => {
                              'title': song['title'] ?? 'Unknown Title',
                              'artist': song['artist'] ?? 'Unknown Artist',
                              'image':
                                  song['image'] ?? 'assets/images/bayaan.jpg',
                              'url': song['url'] ?? '',
                              'icon': '🎵',
                            },
                          )
                          .toList(),
                      isDarkMode,
                      textColor,
                      audioService,
                    ),
              const SizedBox(height: 28),
            ],

            // ==================== SEARCH RESULTS ====================
            if (_searchController.text.isNotEmpty) ...[
              _buildSectionHeader('Songs', textColor),
              const SizedBox(height: 12),
              isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : filteredSongs.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _buildSongList(
                      filteredSongs
                          .map(
                            (song) => {
                              'title': song['title'] ?? 'Unknown Title',
                              'artist': song['artist'] ?? 'Unknown Artist',
                              'image':
                                  song['image'] ?? 'assets/images/bayaan.jpg',
                              'url': song['url'] ?? '',
                              'icon': '🎵',
                            },
                          )
                          .toList(),
                      isDarkMode,
                      textColor,
                      audioService,
                    ),
              const SizedBox(height: 28),
            ],

            // ==================== QUEUE ====================
            _buildSectionHeader('Queue', textColor),
            const SizedBox(height: 12),
            _buildQueueSection(isDarkMode, textColor),

            const SizedBox(height: 28),

            // ==================== RECENTLY PLAYED ====================
            _buildSectionHeader('Recently Played', textColor),
            const SizedBox(height: 12),
            _buildRecentlyPlayedSection(isDarkMode, textColor),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ==================== UPDATED HEADER WIDGET ====================
  Widget _buildHeader(bool isDarkMode, String userName, String userEmail) {
    return Container(
      height: 80, // Slightly increased height to accommodate email
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.teal[900] : Colors.teal,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: const AssetImage('images/logo.png'),
              onBackgroundImageError: (_, __) {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (userEmail.isNotEmpty) // Only show email if available
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== REST OF YOUR METHODS REMAIN EXACTLY THE SAME ====================
  Widget _buildSearchBar(bool isDarkMode, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search songs, artists, playlists...',
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
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAlbumsSection(
    List<Map<String, dynamic>> albums,
    bool isDarkMode,
  ) {
    if (albums.isEmpty) {
      return Container(
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.album,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                'No albums yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create your first album in the Albums tab',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[300],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final albumData = albums[index];
          return _buildAlbumCard(albumData, index, isDarkMode);
        },
      ),
    );
  }

  Widget _buildAlbumCard(
    Map<String, dynamic> albumData,
    int index,
    bool isDarkMode,
  ) {
    final album = albumData['album'] as Album;
    final albumIndex = albumData['albumIndex'] as int;
    
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () async {
          // Load all songs for navigation
          final QuerySnapshot snapshot =
              await FirebaseFirestore.instance.collection('songs').get();
          final allSongs = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'title': doc['title'] ?? 'Unknown',
              'artist': doc['artist'] ?? 'Unknown',
              'image': doc['image'] ?? '',
            };
          }).toList();
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlbumDetailScreen(
                  album: album,
                  albumIndex: albumIndex,
                  allSongs: allSongs,
                ),
              ),
            );
          }
        },
        child: Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Album cover image
                if (albumData['image'] != null && albumData['image'].isNotEmpty)
                  Image.network(
                    albumData['image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultAlbumCover(index),
                  )
                else
                  _buildDefaultAlbumCover(index),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                    ),
                  ),
                ),
                // Album info
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        albumData['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${albumData['songCount']} songs',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAlbumCover(int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.primaries[index % Colors.primaries.length],
            Colors.primaries[index % Colors.primaries.length]
                .withOpacity(0.7),
          ],
        ),
      ),
      child: const Icon(
        Icons.album,
        size: 56,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSongList(
    List<Map<String, dynamic>> songs,
    bool isDarkMode,
    Color textColor,
    AudioService currentAudioService,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _buildSongCard(song, isDarkMode, textColor, index, currentAudioService);
      },
    );
  }

  Widget _buildSongCard(
    Map<String, dynamic> song,
    bool isDarkMode,
    Color textColor,
    int index,
    AudioService currentAudioService,
  ) {
    final audioService = AudioServiceProvider.of(context);
    
    // Check if this song is currently playing
    final isCurrentlyPlaying = audioService.currentSongTitle == song['title'] &&
                                audioService.currentSongArtist == song['artist'];
    
    // Determine card color based on playing status
    Color cardColor;
    if (isCurrentlyPlaying) {
      cardColor = isDarkMode ? Colors.teal[700]! : Colors.teal[300]!;
    } else {
      cardColor = isDarkMode ? Colors.grey[850]! : Colors.teal[200]!;
    }
    
    return Dismissible(
      key: Key('song_${song['id']}_$index'),
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
            Icon(Icons.queue_music, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text('Add to Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        audioService.addToQueue(
          song['url'] ?? '',
          song['title'] ?? 'Unknown',
          song['artist'] ?? 'Unknown',
          song['image'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${song['title']} added to queue'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false; // Don't actually dismiss the item
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
        elevation: isCurrentlyPlaying ? 8 : 3,
        shadowColor: isCurrentlyPlaying 
            ? Colors.teal.withOpacity(0.5) 
            : Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isCurrentlyPlaying
              ? const BorderSide(color: Colors.teal, width: 2)
              : BorderSide.none,
        ),
        color: cardColor,
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
                song['image'] ?? 'assets/images/bayaan.jpg',
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
            song['title']!,
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
              song['artist']!,
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
            if (song['url'] != null && song['url']!.isNotEmpty) {
              try {
                final audioService = AudioServiceProvider.of(context);
                await audioService.playSong(
                  url: song['url']!,
                  title: song['title']!,
                  artist: song['artist']!,
                  image: song['image'],
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

  Widget _buildQueueSection(bool isDarkMode, Color textColor) {
    final audioService = AudioServiceProvider.of(context);
    
    if (audioService.queue.isEmpty) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.queue_music,
                size: 40,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                'No songs in queue',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Swipe songs left to add them to queue',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: audioService.queue.length,
        itemBuilder: (context, index) {
          final song = audioService.queue[index];
          return GestureDetector(
            onTap: () {
              // Remove from queue and play
              audioService.removeFromQueue(index);
              audioService.playSong(
                url: song['url']!,
                title: song['title']!,
                artist: song['artist']!,
                image: song['image'],
              );
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: song['image'] != null && song['image']!.isNotEmpty
                            ? Image.network(
                                song['image']!,
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildDefaultCover(isDarkMode),
                              )
                            : _buildDefaultCover(isDarkMode),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        song['title'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song['artist'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // Queue position badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentlyPlayedSection(bool isDarkMode, Color textColor) {
    final audioService = AudioServiceProvider.of(context);
    
    if (audioService.recentlyPlayed.isEmpty) {
      return _buildEmptyRecentlyPlayed(isDarkMode, textColor);
    }
    
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: audioService.recentlyPlayed.length,
        itemBuilder: (context, index) {
          final song = audioService.recentlyPlayed[index];
          return GestureDetector(
            onTap: () {
              audioService.playSong(
                url: song['url']!,
                title: song['title']!,
                artist: song['artist']!,
                image: song['image'],
              );
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song['image'] != null && song['image']!.isNotEmpty
                        ? Image.network(
                            song['image']!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultCover(isDarkMode),
                          )
                        : _buildDefaultCover(isDarkMode),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song['title'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song['artist'] ?? 'Unknown',
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
          );
        },
      ),
    );
  }

  Widget _buildPublicPlaylistsSection(bool isDarkMode, Color textColor) {
    final albumsBox = Hive.box<Album>('albums');
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<Map<String, dynamic>> publicPlaylists = [];
    
    // Get all public playlists (excluding user's own playlists)
    for (int i = 0; i < albumsBox.length; i++) {
      final album = albumsBox.getAt(i);
      if (album != null && 
          album.isPublic == true && 
          album.userId != currentUser?.uid) {
        // Get album cover
        String? coverImage = album.coverImage;
        if (coverImage == null || coverImage.isEmpty) {
          if (album.songIds != null && album.songIds!.isNotEmpty) {
            final firstSongId = album.songIds!.first;
            final songDoc = songs.firstWhere(
              (s) => s['id'] == firstSongId,
              orElse: () => {},
            );
            coverImage = songDoc['image'] as String?;
          }
        }
        
        publicPlaylists.add({
          'name': album.name ?? 'Unnamed Playlist',
          'image': coverImage,
          'songCount': album.songIds?.length ?? 0,
          'albumIndex': i,
          'album': album,
          'createdBy': album.createdByName ?? 'Unknown',
        });
      }
    }
    
    if (publicPlaylists.isEmpty) {
      return Container(
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.public,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                'No public playlists yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[300],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: publicPlaylists.length,
        itemBuilder: (context, index) {
          final playlistData = publicPlaylists[index];
          return _buildPublicPlaylistCard(playlistData, index, isDarkMode);
        },
      ),
    );
  }

  Widget _buildPublicPlaylistCard(
    Map<String, dynamic> playlistData,
    int index,
    bool isDarkMode,
  ) {
    final album = playlistData['album'] as Album;
    final albumIndex = playlistData['albumIndex'] as int;
    
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () async {
          // Load all songs for navigation
          final QuerySnapshot snapshot =
              await FirebaseFirestore.instance.collection('songs').get();
          final allSongs = snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'title': doc['title'] ?? 'Unknown',
              'artist': doc['artist'] ?? 'Unknown',
              'image': doc['image'] ?? '',
            };
          }).toList();
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlbumDetailScreen(
                  album: album,
                  albumIndex: albumIndex,
                  allSongs: allSongs,
                ),
              ),
            );
          }
        },
        child: Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Album cover image
                if (playlistData['image'] != null && playlistData['image'].isNotEmpty)
                  Image.network(
                    playlistData['image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultAlbumCover(index),
                  )
                else
                  _buildDefaultAlbumCover(index),
                
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
                
                // Album info
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlistData['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.public,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'by ${playlistData['createdBy']}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${playlistData['songCount']} songs',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultCover(bool isDarkMode) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.grey[800]!, Colors.grey[900]!]
              : [Colors.grey[300]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.music_note,
        size: 60,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildEmptyRecentlyPlayed(bool isDarkMode, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No recently played songs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start playing music to see your history',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSongOptionsMenu(BuildContext context, Map<String, dynamic> song, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        song['image'] ?? 'assets/images/bayaan.jpg',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.teal[200],
                            child: const Icon(Icons.music_note, color: Colors.white),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song['title'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song['artist'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.play_circle_outline, color: Colors.teal),
                title: const Text('Play Now'),
                onTap: () async {
                  Navigator.pop(context);
                  if (song['url'] != null && song['url']!.isNotEmpty) {
                    try {
                      final audioService = AudioServiceProvider.of(context);
                      await audioService.playSong(
                        url: song['url']!,
                        title: song['title']!,
                        artist: song['artist']!,
                        image: song['image'],
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Now playing: ${song['title']}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.teal),
                title: const Text('Download'),
                onTap: () async {
                  Navigator.pop(context);
                  
                  print("=== Download button pressed ===");
                  print("Song: ${song['title']}");
                  print("Artist: ${song['artist']}");
                  print("URL: ${song['url']}");
                  print("Image: ${song['image']}");
                  
                  if (song['url'] == null || song['url']!.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error: Song URL is missing!'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                    return;
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Downloading...'),
                          ],
                        ),
                        duration: Duration(seconds: 30),
                      ),
                    );
                  }
                  
                  try {
                    final result = await downloadSongs(
                      url: song['url']!,
                      title: song['title'] ?? 'Unknown',
                      artist: song['artist'] ?? 'Unknown',
                      image: song['image'],
                    );
                    
                    print("Download result: $result");
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result != null
                                ? 'Downloaded successfully to: $result'
                                : 'Download failed or already exists',
                          ),
                          backgroundColor: result != null ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    print("Download exception: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Download error: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.album, color: Colors.teal),
                title: const Text('Add to Album'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToAlbumDialog(song);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showAddToAlbumDialog(Map<String, dynamic> song) {
    final albumsBox = Hive.box<Album>('albums');
    
    if (albumsBox.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No albums yet. Create an album first!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Album'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: albumsBox.length,
            itemBuilder: (context, index) {
              final album = albumsBox.getAt(index);
              if (album == null) return const SizedBox();

              final songIds = album.songIds ?? [];
              final isAlreadyAdded = songIds.contains(song['id']);

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.album, color: Colors.white),
                ),
                title: Text(album.name ?? 'Unnamed Album'),
                subtitle: Text('${songIds.length} songs'),
                trailing: isAlreadyAdded
                    ? const Icon(Icons.check, color: Colors.green)
                    : const Icon(Icons.add),
                onTap: () {
                  if (isAlreadyAdded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Song already in this album'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    songIds.add(song['id']);
                    album.songIds = songIds;
                    album.save();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to ${album.name}'),
                        duration: const Duration(seconds: 2),
                      ),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
