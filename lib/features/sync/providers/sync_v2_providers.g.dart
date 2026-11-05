// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_v2_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firestoreSyncV2ServiceHash() =>
    r'e5fcf6a6511a270b30c7492ae9bf1222b78141fe';

/// See also [firestoreSyncV2Service].
@ProviderFor(firestoreSyncV2Service)
final firestoreSyncV2ServiceProvider =
    Provider<FirestoreSyncV2Service>.internal(
      firestoreSyncV2Service,
      name: r'firestoreSyncV2ServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$firestoreSyncV2ServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirestoreSyncV2ServiceRef = ProviderRef<FirestoreSyncV2Service>;
String _$syncEngineServiceV2Hash() =>
    r'fb5255d006c3d216534123c23a8bd1cd429798f9';

/// See also [syncEngineServiceV2].
@ProviderFor(syncEngineServiceV2)
final syncEngineServiceV2Provider = Provider<SyncEngineServiceV2?>.internal(
  syncEngineServiceV2,
  name: r'syncEngineServiceV2Provider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncEngineServiceV2Hash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncEngineServiceV2Ref = ProviderRef<SyncEngineServiceV2?>;
String _$tripSyncStatusHash() => r'7b6099e0f0c4958b6aafd437a41ebcaaf47a1233';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Stream of sync status for a specific trip (synced, pending, offline or
/// error), starting with its current one.
///
/// Copied from [tripSyncStatus].
@ProviderFor(tripSyncStatus)
const tripSyncStatusProvider = TripSyncStatusFamily();

/// Stream of sync status for a specific trip (synced, pending, offline or
/// error), starting with its current one.
///
/// Copied from [tripSyncStatus].
class TripSyncStatusFamily extends Family<AsyncValue<TripSyncStatus>> {
  /// Stream of sync status for a specific trip (synced, pending, offline or
  /// error), starting with its current one.
  ///
  /// Copied from [tripSyncStatus].
  const TripSyncStatusFamily();

  /// Stream of sync status for a specific trip (synced, pending, offline or
  /// error), starting with its current one.
  ///
  /// Copied from [tripSyncStatus].
  TripSyncStatusProvider call(String tripId) {
    return TripSyncStatusProvider(tripId);
  }

  @override
  TripSyncStatusProvider getProviderOverride(
    covariant TripSyncStatusProvider provider,
  ) {
    return call(provider.tripId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tripSyncStatusProvider';
}

/// Stream of sync status for a specific trip (synced, pending, offline or
/// error), starting with its current one.
///
/// Copied from [tripSyncStatus].
class TripSyncStatusProvider extends AutoDisposeStreamProvider<TripSyncStatus> {
  /// Stream of sync status for a specific trip (synced, pending, offline or
  /// error), starting with its current one.
  ///
  /// Copied from [tripSyncStatus].
  TripSyncStatusProvider(String tripId)
    : this._internal(
        (ref) => tripSyncStatus(ref as TripSyncStatusRef, tripId),
        from: tripSyncStatusProvider,
        name: r'tripSyncStatusProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tripSyncStatusHash,
        dependencies: TripSyncStatusFamily._dependencies,
        allTransitiveDependencies:
            TripSyncStatusFamily._allTransitiveDependencies,
        tripId: tripId,
      );

  TripSyncStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.tripId,
  }) : super.internal();

  final String tripId;

  @override
  Override overrideWith(
    Stream<TripSyncStatus> Function(TripSyncStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TripSyncStatusProvider._internal(
        (ref) => create(ref as TripSyncStatusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        tripId: tripId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<TripSyncStatus> createElement() {
    return _TripSyncStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TripSyncStatusProvider && other.tripId == tripId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, tripId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TripSyncStatusRef on AutoDisposeStreamProviderRef<TripSyncStatus> {
  /// The parameter `tripId` of this provider.
  String get tripId;
}

class _TripSyncStatusProviderElement
    extends AutoDisposeStreamProviderElement<TripSyncStatus>
    with TripSyncStatusRef {
  _TripSyncStatusProviderElement(super.provider);

  @override
  String get tripId => (origin as TripSyncStatusProvider).tripId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
