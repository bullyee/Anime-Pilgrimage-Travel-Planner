import 'dart:async';
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

/// Thrown when sign-in was cancelled by the user.
class AuthCancelledException implements Exception {
  final String message;
  const AuthCancelledException([this.message = 'Sign-in was cancelled.']);

  @override
  String toString() => message;
}

/// Runner function signature for obtaining consent credentials on desktop.
typedef DesktopAuthConsentRunner = Future<AccessCredentials> Function(
  ClientId clientId,
  List<String> scopes,
  http.Client client,
  PromptUserForConsent userPrompt,
);

/// Browser launcher function signature for desktop authentication.
typedef BrowserLauncher = Future<void> Function(Uri uri);

/// Non-sensitive Google Drive scope limiting access strictly to files created
/// or opened by Trip Planner.
const googleDriveFileScope = 'https://www.googleapis.com/auth/drive.file';

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

/// Obtains a short-lived Google OAuth access token granted for
/// [googleDriveFileScope], prompting the user interactively only when needed
/// and [interactive] is true.
final driveAccessTokenProvider =
    Provider<Future<String> Function({bool interactive})>((ref) {
  return ({bool interactive = true}) =>
      ref.read(authControllerProvider.notifier).requestDriveAccessToken(interactive: interactive);
});

class AuthController extends Notifier<AsyncValue<User?>> {
  Future<void> Function()? _cancelDesktopSignIn;
  AccessCredentials? _desktopDriveCredentials;

  @override
  AsyncValue<User?> build() {
    return ref.watch(authStateChangesProvider);
  }

  /// Cancels an in-progress sign-in operation if supported (e.g. desktop loopback server).
  Future<void> cancelSignIn() async {
    final cancel = _cancelDesktopSignIn;
    if (cancel != null) {
      await cancel();
    }
  }

  /// Handles the Google Sign-In flow across all platforms.
  Future<void> signInWithGoogle({
    Duration desktopTimeout = const Duration(minutes: 5),
    DesktopAuthConsentRunner consentRunner = obtainAccessCredentialsViaUserConsent,
    String? testDesktopClientId,
    String? testDesktopClientSecret,
    BrowserLauncher? testBrowserLauncher,
  }) async {
    // 1. Check if we are running on Desktop (Windows, macOS, Linux)
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final credentials = await _obtainDesktopCredentials(
        scopes: const ['email', 'profile', 'openid'],
        desktopTimeout: desktopTimeout,
        consentRunner: consentRunner,
        testDesktopClientId: testDesktopClientId,
        testDesktopClientSecret: testDesktopClientSecret,
        testBrowserLauncher: testBrowserLauncher,
      );

      final credential = GoogleAuthProvider.credential(
        idToken: credentials.idToken,
        accessToken: credentials.accessToken.data,
      );

      final firebaseAuth = ref.read(firebaseAuthProvider);
      await firebaseAuth.signInWithCredential(credential);
    }
    // 2. Standard flow for Mobile (Android/iOS) and Web
    else {
      try {
        final firebaseAuth = ref.read(firebaseAuthProvider);
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

  /// Requests an incremental OAuth access token for [googleDriveFileScope].
  ///
  /// Throws [AuthConfigurationException] if the user is in guest mode or a
  /// desktop build lacks OAuth credentials, and [AuthCancelledException] if
  /// consent is dismissed.
  Future<String> requestDriveAccessToken({
    bool interactive = true,
    Duration desktopTimeout = const Duration(minutes: 5),
    DesktopAuthConsentRunner consentRunner = obtainAccessCredentialsViaUserConsent,
    String? testDesktopClientId,
    String? testDesktopClientSecret,
    BrowserLauncher? testBrowserLauncher,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      throw const AuthConfigurationException(
        'Please sign in with Google before syncing frames to Google Drive.',
      );
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final cached = _desktopDriveCredentials;
      if (cached != null &&
          cached.accessToken.expiry.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 1))) &&
          cached.scopes.contains(googleDriveFileScope)) {
        return cached.accessToken.data;
      }
      if (!interactive) {
        throw const AuthConfigurationException(
          'Google Drive permission expired. Tap Sync via Google Drive again.',
        );
      }
      final fresh = await _obtainDesktopCredentials(
        scopes: const ['email', 'profile', 'openid', googleDriveFileScope],
        desktopTimeout: desktopTimeout,
        consentRunner: consentRunner,
        testDesktopClientId: testDesktopClientId,
        testDesktopClientSecret: testDesktopClientSecret,
        testBrowserLauncher: testBrowserLauncher,
      );
      _desktopDriveCredentials = fresh;
      return fresh.accessToken.data;
    }

    if (kIsWeb) {
      if (!interactive) {
        throw const AuthConfigurationException(
          'Google Drive permission expired. Please authorize Google Drive again.',
        );
      }
      final googleProvider = GoogleAuthProvider()..addScope(googleDriveFileScope);
      try {
        final result = await user.reauthenticateWithPopup(googleProvider);
        final token = (result.credential as OAuthCredential?)?.accessToken;
        if (token == null || token.isEmpty) {
          throw Exception('Google did not return a Drive access token.');
        }
        return token;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          throw const AuthCancelledException();
        }
        rethrow;
      }
    }

    // Mobile (Android / iOS) incremental scope authorization via google_sign_in v7.
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();
    try {
      var googleUser = await googleSignIn.attemptLightweightAuthentication();
      if (googleUser == null) {
        if (!interactive) {
          throw const AuthConfigurationException(
            'Google session expired. Tap Sync via Google Drive to grant access.',
          );
        }
        googleUser = await googleSignIn.authenticate(
          scopeHint: const [googleDriveFileScope],
        );
      }
      final authClient = googleUser.authorizationClient;
      var clientAuth = await authClient.authorizationForScopes(const [googleDriveFileScope]);
      if (clientAuth == null) {
        if (!interactive) {
          throw const AuthConfigurationException(
            'Google Drive permission was not granted yet.',
          );
        }
        clientAuth = await authClient.authorizeScopes(const [googleDriveFileScope]);
      }
      return clientAuth.accessToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      rethrow;
    }
  }

  Future<AccessCredentials> _obtainDesktopCredentials({
    required List<String> scopes,
    required Duration desktopTimeout,
    required DesktopAuthConsentRunner consentRunner,
    String? testDesktopClientId,
    String? testDesktopClientSecret,
    BrowserLauncher? testBrowserLauncher,
  }) async {
    final desktopClientId =
        testDesktopClientId ?? const String.fromEnvironment('DESKTOP_CLIENT_ID');
    final desktopClientSecret =
        testDesktopClientSecret ?? const String.fromEnvironment('DESKTOP_CLIENT_SECRET');

    if (desktopClientId.isEmpty || desktopClientSecret.isEmpty) {
      throw const AuthConfigurationException(
        'Google Sign-In is not configured for this desktop build. You can continue using Trip Planner offline.',
      );
    }

    final httpClient = http.Client();
    final clientId = ClientId(desktopClientId, desktopClientSecret);
    var isCancelled = false;
    Uri? cancelUri;

    _cancelDesktopSignIn = () async {
      isCancelled = true;
      if (cancelUri != null) {
        try {
          await http.get(cancelUri!).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
    };

    try {
      final authFuture = consentRunner(
        clientId,
        scopes,
        httpClient,
        (String url) async {
          final uri = Uri.parse(url);
          final redirectUri = uri.queryParameters['redirect_uri'];
          final state = uri.queryParameters['state'];

          if (redirectUri != null) {
            cancelUri = Uri.parse(redirectUri).replace(
              queryParameters: {
                'state': ?state,
                'error': 'cancelled_by_user',
              },
            );
          }

          if (isCancelled) {
            if (cancelUri != null) {
              try {
                await http.get(cancelUri!).timeout(const Duration(seconds: 2));
              } catch (_) {}
            }
            return;
          }

          try {
            if (testBrowserLauncher != null) {
              await testBrowserLauncher(uri);
            } else if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              throw Exception('Could not launch browser for login.');
            }
          } catch (e) {
            if (cancelUri != null) {
              try {
                await http.get(cancelUri!).timeout(const Duration(seconds: 2));
              } catch (_) {}
            }
            rethrow;
          }
        },
      );

      authFuture.ignore();

      final AccessCredentials credentials = await authFuture.timeout(
        desktopTimeout,
        onTimeout: () {
          if (cancelUri != null) {
            final timeoutUri = cancelUri!.replace(
              queryParameters: {
                ...cancelUri!.queryParameters,
                'error': 'timeout',
              },
            );
            http.get(timeoutUri).catchError((_) => http.Response('', 500));
          }
          throw TimeoutException('Google Sign-In timed out. Please try again.');
        },
      );

      if (isCancelled) {
        throw const AuthCancelledException();
      }
      return credentials;
    } on UserConsentException catch (e) {
      if (isCancelled || e.message.contains('cancelled_by_user')) {
        throw const AuthCancelledException();
      }
      if (e.message.contains('timeout')) {
        throw TimeoutException('Google Sign-In timed out. Please try again.');
      }
      throw Exception('Google Sign-In was not completed: ${e.message}');
    } catch (e) {
      if (isCancelled) {
        throw const AuthCancelledException();
      }
      rethrow;
    } finally {
      _cancelDesktopSignIn = null;
      httpClient.close();
    }
  }

  /// Handles the Sign-Out flow.
  Future<void> signOut() async {
      _desktopDriveCredentials = null;
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
