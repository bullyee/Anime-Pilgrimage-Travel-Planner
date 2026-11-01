// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_sharing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$groupSharingServiceHash() =>
    r'78de856ce20b6d8275a26e350b3bcca6afe3e412';

/// See also [groupSharingService].
@ProviderFor(groupSharingService)
final groupSharingServiceProvider = Provider<GroupSharingService>.internal(
  groupSharingService,
  name: r'groupSharingServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$groupSharingServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GroupSharingServiceRef = ProviderRef<GroupSharingService>;
String _$tripMembersHash() => r'774c8477372c8d58edd56ff0e6cf525197d8477c';

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

/// Watch members list of a shared trip.
///
/// Copied from [tripMembers].
@ProviderFor(tripMembers)
const tripMembersProvider = TripMembersFamily();

/// Watch members list of a shared trip.
///
/// Copied from [tripMembers].
class TripMembersFamily extends Family<AsyncValue<List<TripMember>>> {
  /// Watch members list of a shared trip.
  ///
  /// Copied from [tripMembers].
  const TripMembersFamily();

  /// Watch members list of a shared trip.
  ///
  /// Copied from [tripMembers].
  TripMembersProvider call(String tripId) {
    return TripMembersProvider(tripId);
  }

  @override
  TripMembersProvider getProviderOverride(
    covariant TripMembersProvider provider,
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
  String? get name => r'tripMembersProvider';
}

/// Watch members list of a shared trip.
///
/// Copied from [tripMembers].
class TripMembersProvider extends AutoDisposeStreamProvider<List<TripMember>> {
  /// Watch members list of a shared trip.
  ///
  /// Copied from [tripMembers].
  TripMembersProvider(String tripId)
    : this._internal(
        (ref) => tripMembers(ref as TripMembersRef, tripId),
        from: tripMembersProvider,
        name: r'tripMembersProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tripMembersHash,
        dependencies: TripMembersFamily._dependencies,
        allTransitiveDependencies: TripMembersFamily._allTransitiveDependencies,
        tripId: tripId,
      );

  TripMembersProvider._internal(
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
    Stream<List<TripMember>> Function(TripMembersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TripMembersProvider._internal(
        (ref) => create(ref as TripMembersRef),
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
  AutoDisposeStreamProviderElement<List<TripMember>> createElement() {
    return _TripMembersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TripMembersProvider && other.tripId == tripId;
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
mixin TripMembersRef on AutoDisposeStreamProviderRef<List<TripMember>> {
  /// The parameter `tripId` of this provider.
  String get tripId;
}

class _TripMembersProviderElement
    extends AutoDisposeStreamProviderElement<List<TripMember>>
    with TripMembersRef {
  _TripMembersProviderElement(super.provider);

  @override
  String get tripId => (origin as TripMembersProvider).tripId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
