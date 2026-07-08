import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'album_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_utils.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final Box<Album> _albumsBox = Hive.box<Album>('albums');
  List<Map<String, dynamic>> _allSongs = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _syncAlbumsFromFirestore();
  }

  Future<void> _syncAlbumsFromFirestore() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Clear existing albums from Hive (we'll reload everything)
      await _albumsBox.clear();

      // 1. Fetch user's own albums
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('albums')
          .get();

      for (var doc in userSnapshot.docs) {
        final data = doc.data();
        final album = Album(
          id: doc.id,
          name: data['name'],
          description: data['description'],
          coverImage: data['coverImage'],
          songIds: List<String>.from(data['songIds'] ?? []),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          userId: currentUser.uid,
          isPublic: data['isPublic'] ?? false,
          createdByName: data['createdByName'],
        );
        await _albumsBox.add(album);
      }

      // 2. Fetch all public albums from other users
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var userDoc in allUsersSnapshot.docs) {
        // Skip current user (already loaded)
        if (userDoc.id == currentUser.uid) continue;

        final publicAlbumsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('albums')
            .where('isPublic', isEqualTo: true)
            .get();

        for (var albumDoc in publicAlbumsSnapshot.docs) {
          final data = albumDoc.data();
          final album = Album(
            id: albumDoc.id,
            name: data['name'],
            description: data['description'],
            coverImage: data['coverImage'],
            songIds: List<String>.from(data['songIds'] ?? []),
            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
            userId: userDoc.id,
            isPublic: true,
            createdByName: data['createdByName'],
          );
          await _albumsBox.add(album);
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error syncing albums from Firestore: $e');
    }
  }

  Future<void> _loadSongs() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('songs').get();
      
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        _allSongs = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Unknown',
            'artist': data['artist'] ?? 'Unknown',
            'image': data['image'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading songs: $e');
    }
  }

  void _showCreateAlbumDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedImageUrl;
    bool isPublic = false;
    
    // Check if user is admin
    final isAdmin = await AdminUtils.isCurrentUserAdmin();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Album'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker button
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      // For web, we'll use the path as URL
                      setState(() {
                        selectedImageUrl = image.path;
                      });
                    }
                  },
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal, width: 2),
                    ),
                    child: selectedImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              selectedImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.add_photo_alternate,
                                      size: 40, color: Colors.teal),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 40, color: Colors.teal),
                              SizedBox(height: 8),
                              Text('Add Cover',
                                  style: TextStyle(
                                      color: Colors.teal, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Album Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Public/Private checkbox (admin albums are always public)
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.teal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin playlists are always public',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  CheckboxListTile(
                    title: const Text('Make this playlist public'),
                    subtitle: const Text(
                      'Public playlists are visible to all users',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: isPublic,
                    onChanged: (value) {
                      setState(() {
                        isPublic = value ?? false;
                      });
                    },
                    activeColor: Colors.teal,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _createAlbum(
                    nameController.text.trim(),
                    descriptionController.text.trim(),
                    selectedImageUrl,
                    isAdmin ? true : isPublic, // Admin albums always public
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAlbum(String name, String description, String? coverImageUrl, bool isPublic) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create albums')),
      );
      return;
    }

    // Get user's name for the createdByName field
    final userName = await AdminUtils.getUserName(currentUser.uid);

    final albumId = const Uuid().v4();
    final album = Album(
      id: albumId,
      name: name,
      description: description.isEmpty ? null : description,
      coverImage: coverImageUrl,
      songIds: [],
      createdAt: DateTime.now(),
      userId: currentUser.uid,
      isPublic: isPublic,
      createdByName: userName,
    );

    try {
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('albums')
          .doc(albumId)
          .set({
        'name': name,
        'description': description.isEmpty ? null : description,
        'coverImage': coverImageUrl,
        'songIds': [],
        'isPublic': isPublic,
        'createdByName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save to Hive
      await _albumsBox.add(album);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Album "$name" created')),
        );
      }
    } catch (e) {
      print('Error creating album: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating album: $e')),
        );
      }
    }
  }

  void _deleteAlbum(Album album, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Album'),
        content: Text('Are you sure you want to delete "${album.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser != null && album.id != null) {
                try {
                  // Delete from Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('albums')
                      .doc(album.id)
                      .delete();
                  
                  // Delete from Hive
                  await _albumsBox.deleteAt(index);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Album "${album.name}" deleted')),
                    );
                  }
                } catch (e) {
                  print('Error deleting album: $e');
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting album: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAlbum(Album album, int index) async {
    final nameController = TextEditingController(text: album.name);
    final descriptionController = TextEditingController(text: album.description ?? '');
    String? selectedImageUrl = album.coverImage;
    bool isPublic = album.isPublic ?? false;
    
    // Check if user is admin
    final isAdmin = await AdminUtils.isCurrentUserAdmin();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Album'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker button
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setState(() {
                        selectedImageUrl = image.path;
                      });
                    }
                  },
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal, width: 2),
                    ),
                    child: selectedImageUrl != null && selectedImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              selectedImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.add_photo_alternate,
                                      size: 40, color: Colors.teal),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 40, color: Colors.teal),
                              SizedBox(height: 8),
                              Text('Add Cover',
                                  style: TextStyle(
                                      color: Colors.teal, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Album Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Public/Private checkbox
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.teal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin playlists are always public',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  CheckboxListTile(
                    title: const Text('Make this playlist public'),
                    subtitle: const Text(
                      'Public playlists are visible to all users',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: isPublic,
                    onChanged: (value) {
                      setState(() {
                        isPublic = value ?? false;
                      });
                    },
                    activeColor: Colors.teal,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null && album.id != null) {
                    try {
                      // Update Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .collection('albums')
                          .doc(album.id)
                          .update({
                        'name': nameController.text.trim(),
                        'description': descriptionController.text.trim().isEmpty 
                            ? null 
                            : descriptionController.text.trim(),
                        'coverImage': selectedImageUrl,
                        'isPublic': isAdmin ? true : isPublic,
                      });
                      
                      // Update Hive
                      album.name = nameController.text.trim();
                      album.description = descriptionController.text.trim().isEmpty 
                          ? null 
                          : descriptionController.text.trim();
                      album.coverImage = selectedImageUrl;
                      album.isPublic = isAdmin ? true : isPublic;
                      await album.save();
                      
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Album updated')),
                        );
                      }
                    } catch (e) {
                      print('Error updating album: $e');
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating album: $e')),
                        );
                      }
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder(
        valueListenable: _albumsBox.listenable(),
        builder: (context, Box<Album> box, _) {
          // Filter albums by current user
          final userAlbums = <int, Album>{};
          if (currentUser != null) {
            for (int i = 0; i < box.length; i++) {
              final album = box.getAt(i);
              if (album != null && album.userId == currentUser.uid) {
                userAlbums[i] = album;
              }
            }
          }
          
          if (userAlbums.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.album,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Albums Yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first album',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: userAlbums.length,
            itemBuilder: (context, index) {
              final albumIndex = userAlbums.keys.elementAt(index);
              final album = userAlbums.values.elementAt(index);

              final songCount = album.songIds?.length ?? 0;
              final coverImage = album.coverImage ?? _getAlbumCover(album);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlbumDetailScreen(
                        album: album,
                        albumIndex: albumIndex,
                        allSongs: _allSongs,
                      ),
                    ),
                  );
                },
                onLongPress: () => _showAlbumOptions(album, albumIndex),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: coverImage != null
                              ? Image.network(
                                  coverImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildDefaultAlbumCover(),
                                )
                              : _buildDefaultAlbumCover(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.name ?? 'Unnamed Album',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAlbumDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String? _getAlbumCover(Album album) {
    // Get the first song's image as album cover
    if (album.songIds != null && album.songIds!.isNotEmpty) {
      final firstSongId = album.songIds!.first;
      final song = _allSongs.firstWhere(
        (s) => s['id'] == firstSongId,
        orElse: () => {},
      );
      return song['image'] as String?;
    }
    return null;
  }

  Widget _buildDefaultAlbumCover() {
    return Container(
      color: Colors.teal.withOpacity(0.1),
      child: const Icon(
        Icons.album,
        size: 80,
        color: Colors.teal,
      ),
    );
  }

  void _showAlbumOptions(Album album, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Album'),
              onTap: () {
                Navigator.pop(context);
                _editAlbum(album, index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Album', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteAlbum(album, index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
