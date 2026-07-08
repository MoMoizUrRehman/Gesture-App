import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUtils {
  static Future<bool> isAdmin(String? userId) async {
    if (userId == null) return false;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['isAdmin'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  static Future<bool> isCurrentUserAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    return await isAdmin(currentUser?.uid);
  }

  static Future<String?> getUserName(String? userId) async {
    if (userId == null) return null;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['name'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching user name: $e');
      return null;
    }
  }

  /// Creates or updates a user to admin status
  /// Call this once to set up your admin account
  static Future<void> setAdminStatus(String userId, bool isAdmin) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'isAdmin': isAdmin,
      }, SetOptions(merge: true));
      print('Admin status updated for user $userId: $isAdmin');
    } catch (e) {
      print('Error setting admin status: $e');
    }
  }
}
