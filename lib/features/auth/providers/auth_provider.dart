import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// --- Desktop specific imports ---
import 'package:googleapis_auth/auth_io.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

part 'auth_provider.g.dart';

/// Thrown when authentication is not configured for the current platform/build.
class AuthConfigurationException implements Exception {
  final String message;
  const AuthConfigurationException(this.message);

  @override
  String toString() => message;
}

/// Checks whether desktop OAuth credentials are configured at compile-time.
bool get isDesktopAuthAvailable =>
    const String.fromEnvironment('DESKTOP_CLIENT_ID').isNotEmpty &&
    const String.fromEnvironment('DESKTOP_CLIENT_SECRET').isNotEmpty;


// --- [Providers] ---

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) {
  return FirebaseAuth.instance;
}

@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}

@Riverpod(keepAlive: true)
String currentUserId(CurrentUserIdRef ref) {
  // Watch the auth state. It returns an AsyncValue<User?>.
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.valueOrNull;

  if (user != null) {
    return user.uid;
  }

  // FALLBACK: For offline-first functionality when the user hasn't signed in.
  // TODO: Upgrade this to a persistent Device UUID stored in SharedPreferences.
  return 'guest_local_user';
}

// --- [Controller] ---

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<User?>>(() {
  return AuthController();
});

class AuthController extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() {
    return ref.watch(authStateChangesProvider);
  }

  /// Handles the Google Sign-In flow across all platforms.
  Future<void> signInWithGoogle() async {
    final firebaseAuth = ref.read(firebaseAuthProvider);

    // 1. Check if we are running on Desktop (Windows, macOS, Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      
      // Fetch credentials injected during compile-time
      const desktopClientId = String.fromEnvironment('DESKTOP_CLIENT_ID');
      const desktopClientSecret = String.fromEnvironment('DESKTOP_CLIENT_SECRET');
      
      // Safety check to ensure credentials are provided
      if (desktopClientId.isEmpty || desktopClientSecret.isEmpty) {
        throw const AuthConfigurationException(
          'Google Sign-In is not configured for this desktop build. You can continue using Trip Planner offline.',
        );
      }

      final scopes = ['email', 'profile', 'openid'];
      final httpClient = http.Client();
      
      // Use the securely injected credentials
      final clientId = ClientId(desktopClientId, desktopClientSecret);

      try {
        final AccessCredentials credentials = await obtainAccessCredentialsViaUserConsent(
          clientId,
          scopes,
          httpClient,
          (String url) async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              throw Exception('Could not launch browser for login.');
            }
          },
        );

        final credential = GoogleAuthProvider.credential(
          idToken: credentials.idToken,
          accessToken: credentials.accessToken.data,
        );

        await firebaseAuth.signInWithCredential(credential);
      } finally {
        httpClient.close();
      }

    }
    // 2. Standard flow for Mobile (Android/iOS) and Web
    else {
      try {
        // ==========================================
        // PLATFORM FORK: The Ultimate Solution
        // ==========================================
        if (kIsWeb) {
          // WEB PLATFORM: Completely bypass the restrictive google_sign_in package.
          // Firebase Auth natively handles the Web OAuth popup securely, 
          // allowing our custom Flutter button to work perfectly without UnimplementedErrors.
          final googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          
          // Automatically uses the Web Client ID configured in your FirebaseOptions (main.dart)
          await firebaseAuth.signInWithPopup(googleProvider);
          
        } else {
          // MOBILE PLATFORM: Use the strict v7 google_sign_in package flow.
          final googleSignIn = GoogleSignIn.instance;
          
          // Mobile usually relies on google-services.json for the Client ID.
          await googleSignIn.initialize(); 

          // Throws exception if user cancels
          final googleUser = await googleSignIn.authenticate();
          
          // idToken is retrieved synchronously
          final googleAuth = googleUser.authentication;

          // Request specific scopes dynamically to obtain the Access Token
          final clientAuth = await googleUser.authorizationClient.authorizeScopes([
            'email', 
            'profile',
          ]);

          // Build the Firebase credential
          final credential = GoogleAuthProvider.credential(
            accessToken: clientAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          await firebaseAuth.signInWithCredential(credential);
        }
      } catch (e) {
        throw Exception('Google Sign-In process was aborted or failed: $e');
      }
    }
  }

  /// Handles the Sign-Out flow.
  Future<void> signOut() async {
      try {
        // Retrieve the FirebaseAuth instance from your provider
        final firebaseAuth = ref.read(firebaseAuthProvider);

        // Mobile (Android/iOS) requires GoogleSignIn cleanup to clear the locally cached account.
        if (!kIsWeb && !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          await GoogleSignIn.instance.signOut();
        }

        // CRITICAL FIX: Explicitly terminate the Firebase session on ALL platforms.
        // This is the actual trigger for authStateChanges() to emit a null user.
        await firebaseAuth.signOut();
        
      } catch (e) {
        throw Exception('Sign-out process failed: $e');
      }
    }
}