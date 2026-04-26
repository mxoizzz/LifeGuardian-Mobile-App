import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- AUTH STATE STREAM ---
  Stream<User?> get userStream => _auth.authStateChanges();

  // --- GOOGLE SIGN IN (Fast/Automatic for returning users) ---
  // Use this in login_screen.dart
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      return await _linkWithFirebase(googleUser);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // --- GOOGLE SIGN UP (Forces Account Selection for new users) ---
  // Use this in register_screen.dart
  Future<User?> signUpWithGoogle() async {
    try {
      // Clear previous session to force the account picker
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      return await _linkWithFirebase(googleUser);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Private helper to convert Google User to Firebase User
  Future<User?> _linkWithFirebase(GoogleSignInAccount googleUser) async {
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    UserCredential result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  // --- EMAIL/PASSWORD SIGN IN ---
  Future<User?> signIn({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // --- EMAIL/PASSWORD REGISTER ---
  Future<User?> register({required String email, required String password}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    try {
      // Disconnect revokes the token so the next login is fresh
      await _googleSignIn.disconnect();
      await _auth.signOut();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // --- ERROR HANDLER ---
  String _handleError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found': return 'No user found for that email.';
        case 'wrong-password': return 'Wrong password provided.';
        case 'email-already-in-use': return 'Account already exists.';
        case 'weak-password': return 'Password is too weak.';
        default: return error.message ?? 'An error occurred.';
      }
    }
    return error.toString();
  }
}