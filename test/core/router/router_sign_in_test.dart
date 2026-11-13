import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/router/app_router.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
}

void main() {
  test('signing in and out keeps the same router, so the screens under the current one stay', () async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);
    final container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => auth.stream),
    ]);
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    auth.add(null);
    await pumpEventQueue();
    auth.add(_FakeUser());
    await pumpEventQueue();
    expect(container.read(routerProvider), same(router));

    auth.add(null);
    await pumpEventQueue();
    expect(container.read(routerProvider), same(router));
  });
}
