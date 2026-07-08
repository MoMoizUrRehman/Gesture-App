import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/adapters.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'audio_service.dart';
import 'mini_player.dart';
import 'package:hive/hive.dart';
import 'downloads.dart';
import 'albums_screen.dart';
import 'songs_screen.dart';
import 'profile_tab.dart';
part 'main.g.dart'; // if your model is in main.dart

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  String? artist;

  @HiveField(1)
  String? image;

  @HiveField(2)
  String? title;

  @HiveField(3)
  String? path;

  @HiveField(4)
  String? id;
  Song({
    required this.artist,
    required this.image,
    required this.title,
    required this.path,
    required this.id,
  });
}

@HiveType(typeId: 1)
class Album extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? coverImage;

  @HiveField(4)
  List<String>? songIds; // List of song IDs in this album

  @HiveField(5)
  DateTime? createdAt;

  @HiveField(6)
  String? userId; // User ID who created this album

  @HiveField(7)
  bool? isPublic; // Whether this album is public or private

  @HiveField(8)
  String? createdByName; // Name of the user who created this album

  Album({
    required this.id,
    required this.name,
    this.description,
    this.coverImage,
    this.songIds,
    this.createdAt,
    this.userId,
    this.isPublic,
    this.createdByName,
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(SongAdapter());
  Hive.registerAdapter(AlbumAdapter());
  await Hive.openBox<Song>('downloads');
  await Hive.openBox<Album>('albums');

  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // still waiting for Firebase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // logged in
          if (snapshot.hasData) {
            return HomeManager(user: snapshot.data!);
          }

          // not logged in
          return const LogIn();
        },
      ),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Song>('downloads');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<Song> box, _) {
        final songs = box.values.toList();

        print("DownloadsPage: Rebuilding with ${songs.length} songs");

        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 80,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No download  `s yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Download songs to play offline',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    print("Debug: Box length = ${box.length}");
                    print("Debug: Box keys = ${box.keys.toList()}");
                    print("Debug: Box values = ${box.values.toList()}");
                  },
                  child: const Text('Debug: Check Hive'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    print("Testing download with sample URL...");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Testing download...')),
                    );

                    // Test with a small public MP3 file
                    final result = await downloadSongs(
                      url:
                          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                      title: 'Test Song',
                      artist: 'Test Artist',
                      image: null,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result != null
                                ? 'Test download successful!'
                                : 'Test download failed',
                          ),
                          backgroundColor: result != null
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Test Download Function'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: songs.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final song = songs[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song.image != null
                      ? Image.asset(
                          song.image!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 56,
                              height: 56,
                              color: Colors.teal[200],
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.teal[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                          ),
                        ),
                ),
                title: Text(
                  song.title ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    song.artist ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 28),
                      color: Colors.teal,
                      onPressed: () async {
                        if (song.path != null) {
                          try {
                            final audioService = AudioServiceProvider.of(
                              context,
                            );
                            await audioService.playSong(
                              url: song.path!,
                              title: song.title ?? 'Unknown',
                              artist: song.artist ?? 'Unknown',
                              image: song.image,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Now playing: ${song.title}'),
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
                    IconButton(
                      icon: const Icon(Icons.delete, size: 24),
                      color: Colors.red[400],
                      onPressed: () {
                        _showDeleteDialog(context, song, isDarkMode);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Song song, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          'Delete Download',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete "${song.title}"?',
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await song.delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class HomeManager extends StatefulWidget {
  final User user;
  const HomeManager({super.key, required this.user});

  @override
  State<HomeManager> createState() => _HomeManagerState();
}

class _HomeManagerState extends State<HomeManager> {
  bool isDarkMode = true; // Default to dark mode
  int ind = 0;
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;
  late final AudioService _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _fetchUserData();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      if (!mounted) return; // Check if widget is still mounted

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoadingUserData = false;
        });
      } else {
        // If no Firestore doc, use Firebase Auth data
        setState(() {
          userData = {
            'name': widget.user.displayName ?? 'User',
            'email': widget.user.email ?? '',
          };
          isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (!mounted) return; // Check if widget is still mounted
      
      setState(() {
        userData = {
          'name': widget.user.displayName ?? 'User',
          'email': widget.user.email ?? '',
        };
        isLoadingUserData = false;
      });
    }
  }

  void toggleTheme(bool value) => setState(() => isDarkMode = value);

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> tabs = [
      HomeScreen(userData: userData),
      DownloadsPage(),
      const AlbumsScreen(),
      const SongsScreen(),
      ProfileTab(userData: userData, onLogout: () async {
        await _audioService.stop();
        await FirebaseAuth.instance.signOut();
      }),
      SettingsScreen(
        isDarkMode: isDarkMode,
        onThemeChanged: toggleTheme,
        onLogout: () async {
          await _audioService.stop();
          await FirebaseAuth.instance.signOut();
        },
      ),
    ];

    return AudioServiceProvider(
      audioService: _audioService,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: tabs[ind]),
                MiniPlayer(),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: ind,
            onTap: (index) => setState(() => ind = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.teal,
            unselectedItemColor: Colors.grey[600],
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.download_outlined),
                label: 'Downloads',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.album), label: 'Albums'),
              BottomNavigationBarItem(
                icon: Icon(Icons.music_note),
                label: 'Songs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
