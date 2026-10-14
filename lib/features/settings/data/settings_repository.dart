import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

final settingsProvider = StreamProvider<UserSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

class SettingsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;

  DocumentReference get _settingsDoc =>
      _firestore.collection('users').doc(_userId).collection('settings').doc('user_settings');

  Stream<UserSettings> watchSettings() {
    return _settingsDoc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return UserSettings.defaultSettings();
      }
      return UserSettings.fromMap(snapshot.data() as Map<String, dynamic>);
    });
  }

  Future<UserSettings> getSettings() async {
    try {
      final doc = await _settingsDoc.get();
      if (!doc.exists || doc.data() == null) {
        return UserSettings.defaultSettings();
      }
      return UserSettings.fromMap(doc.data() as Map<String, dynamic>);
    } catch (_) {
      return UserSettings.defaultSettings();
    }
  }

  Future<void> updateSettings(UserSettings settings) async {
    await _settingsDoc.set(settings.toMap(), SetOptions(merge: true));
  }
}
