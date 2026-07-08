
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'dart:typed_data';

// import 'firebase_options.dart'; // your working Firebase configflut

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: UploadScreen(),
//     );
//   }
// }

// class UploadScreen extends StatefulWidget {
//   const UploadScreen({super.key});

//   @override
//   State<UploadScreen> createState() => _UploadScreenState();
// }

// class _UploadScreenState extends State<UploadScreen> {
//   bool isUploading = false;
//   String downloadUrl = '';

//   Future<void> uploadAudio() async {
//     try {
//       setState(() => isUploading = true);

//       // Load file from assets
//       final ByteData audioData = await rootBundle.load('audios/maand-bayaan.mp3');
//       final Uint8List bytes = audioData.buffer.asUint8List();

//       // Create Firebase Storage reference
//       final ref = FirebaseStorage.instance.ref().child('audios/maand-bayaan.mp3');

//       // Upload the bytes
//       await ref.putData(bytes, SettableMetadata(contentType: 'audio/mpeg'));

//       // Get download URL
//       final url = await ref.getDownloadURL();

//       setState(() {
//         downloadUrl = url;
//         isUploading = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text(' Upload successful')),
//       );
//     } catch (e) {
//       setState(() => isUploading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Upload Audio to Firebase')),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               if (isUploading)
//                 const CircularProgressIndicator()
//               else
//                 ElevatedButton.icon(
//                   onPressed: uploadAudio,
//                   icon: const Icon(Icons.cloud_upload),
//                   label: const Text('Upload maand-bayaan.mp3'),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//                   ),
//                 ),
//               const SizedBox(height: 20),
//               if (downloadUrl.isNotEmpty)
//                 SelectableText(
//                   'Download URL:\n$downloadUrl',
//                   textAlign: TextAlign.center,
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
