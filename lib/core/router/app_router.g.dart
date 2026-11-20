// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$routerHash() => r'd5ab64bfdedc9bd78cdef40b211efaa7e7292ce1';

/// The app's one router. It lives as long as the app: signing in or out
/// only re-runs [GoRouter.redirect] (through `refreshListenable`), so the
/// screen the user signed in from, and everything under it, stays where it
/// was, with its back button. (Rebuilding the router on sign-in used to
/// restart navigation at that screen with nothing to go back to.)
///
/// Copied from [router].
@ProviderFor(router)
final routerProvider = Provider<GoRouter>.internal(
  router,
  name: r'routerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$routerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RouterRef = ProviderRef<GoRouter>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
