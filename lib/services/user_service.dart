import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/user_model.dart';
import '../model/emergency_contact.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return AppUser.fromMap(uid, doc.data()!);
    }
    return null;
  }

  Future<void> updateProfileImage({
    required String uid,
    required String imageUrl,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'profileImageUrl': imageUrl,
    });
  }

  Future<void> addEmergencyContact({
    required String uid,
    required EmergencyContact contact,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('emergency_contacts')
        .add(contact.toMap());
  }

  Future<void> deleteEmergencyContact(String uid, String contactId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      throw Exception("Failed to delete contact: $e");
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('emergency_contacts')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map(
          (doc) => EmergencyContact.fromMap(
        doc.id,
        doc.data(),
      ),
    )
        .toList();
  }

  Future<void> markContactVerified(String contactId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('emergency_contacts')
        .doc(contactId)
        .update({'verified': true});
  }

  Future<void> updateLocationSharing({
    required String uid,
    required bool enabled,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'isLocationSharingEnabled': enabled,
    });
  }


}
