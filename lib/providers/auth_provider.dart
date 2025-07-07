import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});



final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Email Sign-in Failed: $e");
      return null;
    }
  }

  Future<User?> registerWithEmail(
    String email,
    String password,
    String firstName,
    String lastName,
    String phone,
    String dob,
    String gender) async {
  try {
    UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = userCredential.user;
    if (user != null) {
      await saveUserData(user.uid, firstName, lastName, email, phone, dob, gender);
    }
    return user;
  } catch (e) {
    print("Email Registration Failed: $e");
    return null;
  }
}


Future<void> saveUserData(
    String uid,
    String firstName,
    String lastName,
    String email,
    String phone,
    String dob,
    String gender) async {
  try {
    await _firestore.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'dob': dob,
      'gender': gender,
      'createdAt': FieldValue.serverTimestamp(), // Store creation timestamp
    });
  } catch (e) {
    print("Failed to save user data: $e");
  }
}


  Future<void> signOut() async {
    await _auth.signOut();
  }
}

