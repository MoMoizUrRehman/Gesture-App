import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'audio_service.dart';
import 'mini_player.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  final int albumIndex;
  final List<Map<String, dynamic>> allSongs;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.albumIndex,
    required this.allSongs,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<Map<String, dynamic>> _albumSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumSongs();
  }

  Future<void> _loadAlbumSongs() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> songs = [];
      final songIds = widget.album.songIds ?? [];

      for (String songId in songIds) {
        final doc = await FirebaseFirestore.instance
            .collection('songs')
            .doc(songId)
            .get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          songs.add({
            'id': doc.id,
            'title': data['title'] ?? 'Unknown',
            'artist': data['artist'] ?? 'Unknown',
            'image': data['image'] ?? '',
            'url': data['url'] ?? data['path'] ?? '', // Try 'url' first, fallback to 'path'
          });
        }
      }

      setState(() {
        _albumSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading album songs: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddSongsDialog() {
    final existingSongIds = widget.album.songIds ?? [];
    final availableSongs = widget.allSongs
        .where((song) => !existingSongIds.contains(song['id']))
        .toList();

    if (availableSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All songs are already in this album')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Songs to Album'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableSongs.length,
            itemBuilder: (context, index) {
              final song = availableSongs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: song['image'] != null && song['image'].isNotEmpty
                      ? NetworkImage(song['image'])
                      : null,
                  child: song['image'] == null || song['image'].isEmpty
                      ? const Icon(Icons.music_note)
                      : null,
                ),
                title: Text(song['title'] ?? 'Unknown'),
                subtitle: Text(song['artist'] ?? 'Unknown'),
                onTap: () {
                  _addSongToAlbum(song['id']);
                  Navigator.pop(context);
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

  Future<void> _addSongToAlbum(String songId) async {
    final songIds = widget.album.songIds ?? [];
    if (!songIds.contains(songId)) {
      songIds.add(songId);
      widget.album.songIds = songIds;
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && widget.album.id != null) {
        try {
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('albums')
              .doc(widget.album.id)
              .update({
            'songIds': songIds,
          });
          
          // Update Hive
          await widget.album.save();
          _loadAlbumSongs();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Song added to album')),
            );
          }
        } catch (e) {
          print('Error adding song to album: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error adding song: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _removeSongFromAlbum(String songId) async {
    final songIds = widget.album.songIds ?? [];
    songIds.remove(songId);
    widget.album.songIds = songIds;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && widget.album.id != null) {
      try {
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('albums')
            .doc(widget.album.id)
            .update({
          'songIds': songIds,
        });
        
        // Update Hive
        await widget.album.save();
        _loadAlbumSongs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song removed from album')),
          );
        }
      } catch (e) {
        print('Error removing song from album: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing song: $e')),
          );
        }
      }
    }
  }

  void _playAllSongs() {
    if (_albumSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs in this album')),
      );
      return;
    }

    final audioService = AudioServiceProvider.of(context);
    final firstSong = _albumSongs.first;
    audioService.playSong(
      url: firstSong['url'],
      title: firstSong['title'],
      artist: firstSong['artist'],
      image: firstSong['image'],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing ${widget.album.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = AudioServiceProvider.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: Colors.teal,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.album.name ?? 'Unnamed Album',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_albumSongs.isNotEmpty && _albumSongs.first['image'] != null)
                          Image.network(
                            _albumSongs.first['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultBackground(),
                    )
                  else
                    _buildDefaultBackground(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.album.description != null &&
                      widget.album.description!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.album.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _playAllSongs,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showAddSongsDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Songs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${_albumSongs.length} ${_albumSongs.length == 1 ? 'Song' : 'Songs'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_albumSongs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No songs in this album',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showAddSongsDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Songs'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _albumSongs[index];
                  return Dismissible(
                    key: Key(song['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) {
                      _removeSongFromAlbum(song['id']);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: song['image'] != null &&
                                song['image'].isNotEmpty
                            ? NetworkImage(song['image'])
                            : null,
                        child: song['image'] == null || song['image'].isEmpty
                            ? const Icon(Icons.music_note)
                            : null,
                      ),
                      title: Text(song['title'] ?? 'Unknown'),
                      subtitle: Text(song['artist'] ?? 'Unknown'),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          audioService.playSong(
                            url: song['url'],
                            title: song['title'],
                            artist: song['artist'],
                            image: song['image'],
                          );
                        },
                      ),
                      onTap: () {
                        audioService.playSong(
                          url: song['url'],
                          title: song['title'],
                          artist: song['artist'],
                          image: song['image'],
                        );
                      },
                    ),
                  );
                },
                childCount: _albumSongs.length,
              ),
            ),
              ],
            ),
          ),
          MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildDefaultBackground() {
    return Container(
      color: Colors.teal.withOpacity(0.3),
      child: const Icon(
        Icons.album,
        size: 120,
        color: Colors.white54,
      ),
    );
  }
}
