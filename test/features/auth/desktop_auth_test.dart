import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/auth/screens/login_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  group('Auth Exceptions & Contract', () {
    test('AuthCancelledException defaults and formatted message', () {
      const exDefault = AuthCancelledException();
      expect(exDefault.message, 'Sign-in was cancelled.');
      expect(exDefault.toString(), 'Sign-in was cancelled.');

      const exCustom = AuthCancelledException('Custom cancel message');
      expect(exCustom.message, 'Custom cancel message');
      expect(exCustom.toString(), 'Custom cancel message');
    });

    test('cancelSignIn is a safe no-op when no sign-in is active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await expectLater(controller.cancelSignIn(), completes);
    });

    test('cancelSignIn handles rapid double-calls safely', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      await expectLater(
        Future.wait([
          controller.cancelSignIn(),
          controller.cancelSignIn(),
        ]),
        completes,
      );
    });
  });

  group('Desktop OAuth Cancellation and Timeout Logic', () {
    test('User cancellation sends cancel request and throws AuthCancelledException', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      final server = await HttpServer.bind('localhost', 0);
      final serverPort = server.port;

      String? receivedError;
      String? receivedState;

      // Listen on local server for the cancel ping
      final serverFuture = server.first.then((request) async {
        receivedError = request.uri.queryParameters['error'];
        receivedState = request.uri.queryParameters['state'];
        request.response.statusCode = 500;
        await request.response.close();
        await server.close();
      });

      // Start sign in with a fake consent runner that binds to our local server
      final signInFuture = controller.signInWithGoogle(
        testDesktopClientId: 'test-client-id',
        testDesktopClientSecret: 'test-client-secret',
        testBrowserLauncher: (_) async {},
        consentRunner: (clientId, scopes, client, userPrompt) async {
          // Trigger prompt with loopback URI
          userPrompt(
            'https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=http%3A%2F%2Flocalhost%3A$serverPort&state=custom_test_state',
          );
          await serverFuture;
          throw UserConsentException('Error occurred while obtaining access credentials: $receivedError');
        },
      );

      // Give event loop time to set up prompt callback
      await pumpEventQueue();

      // Cancel the sign-in
      await controller.cancelSignIn();

      // Expect signInWithGoogle to cleanly throw AuthCancelledException
      await expectLater(signInFuture, throwsA(isA<AuthCancelledException>()));

      // Verify server received the cancel request with correct state and error
      expect(receivedError, 'cancelled_by_user');
      expect(receivedState, 'custom_test_state');
    });

    test('OAuth timeout fires and throws TimeoutException', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      final server = await HttpServer.bind('localhost', 0);
      final serverPort = server.port;

      String? receivedError;

      // Server will receive the timeout ping
      final serverFuture = server.first.then((request) async {
        receivedError = request.uri.queryParameters['error'];
        request.response.statusCode = 500;
        await request.response.close();
        await server.close();
      });

      final signInFuture = controller.signInWithGoogle(
        desktopTimeout: const Duration(milliseconds: 100),
        testDesktopClientId: 'test-client-id',
        testDesktopClientSecret: 'test-client-secret',
        testBrowserLauncher: (_) async {},
        consentRunner: (clientId, scopes, client, userPrompt) async {
          userPrompt(
            'https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=http%3A%2F%2Flocalhost%3A$serverPort&state=timeout_state',
          );
          // Never complete to force timeout
          await Completer<AccessCredentials>().future;
          throw Exception('Should not reach here');
        },
      );

      await expectLater(signInFuture, throwsA(isA<TimeoutException>()));
      await serverFuture;
      expect(receivedError, 'timeout');
    });
  });

  group('LoginScreen Desktop UI Interaction', () {
    testWidgets('LoginScreen shows cancel button during sign-in and resets upon cancel',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeController = _FakeAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, "Sign in with Google" button is present and active
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Cancel sign-in'), findsNothing);

      // Tap Sign in
      await tester.tap(find.text('Sign in with Google'));
      await tester.pump(); // Start async work

      // Loading state: "Waiting for sign-in in browser..." and "Cancel sign-in" button appear
      expect(find.text('Waiting for sign-in in browser...'), findsOneWidget);
      expect(find.text('Cancel sign-in'), findsOneWidget);

      // Tap Cancel sign-in
      await tester.tap(find.text('Cancel sign-in'));
      await tester.pump(); // Trigger cancel

      // Resolves cancellation in controller
      fakeController.completeCancel();
      await tester.pumpAndSettle();

      // UI returns to initial state without displaying error snackbar
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Cancel sign-in'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('LoginScreen shows friendly SnackBar when sign-in times out',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeController = _FakeAuthController(
        failWith: TimeoutException('Sign-in timed out. Please try again.'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign in
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // SnackBar with timeout message is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Sign-in timed out. Please try again.'), findsOneWidget);
      // Button returns to idle
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });
}

class _FakeAuthController extends AuthController {
  final Exception? failWith;
  Completer<void>? _signInCompleter;

  _FakeAuthController({this.failWith});

  @override
  AsyncValue<User?> build() => const AsyncData(null);

  @override
  Future<void> signInWithGoogle({
    Duration desktopTimeout = const Duration(minutes: 2),
    DesktopAuthConsentRunner consentRunner = obtainAccessCredentialsViaUserConsent,
    String? testDesktopClientId,
    String? testDesktopClientSecret,
    BrowserLauncher? testBrowserLauncher,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    _signInCompleter = Completer<void>();
    await _signInCompleter!.future;
  }

  @override
  Future<void> cancelSignIn() async {
    if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
      _signInCompleter!.completeError(const AuthCancelledException());
    }
  }

  void completeCancel() {
    if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
      _signInCompleter!.completeError(const AuthCancelledException());
    }
  }
}
