import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_invite.dart';
import '../models/trip_member.dart';
import '../providers/group_sharing_providers.dart';
import '../services/group_sharing_service.dart';

class JoinTripState {
  final String code;
  final TripInvite? invite;
  final bool isLoading;
  final bool isJoining;
  final bool isJoined;
  final String? joinedTripId;
  final String? errorMessage;

  const JoinTripState({
    this.code = '',
    this.invite,
    this.isLoading = false,
    this.isJoining = false,
    this.isJoined = false,
    this.joinedTripId,
    this.errorMessage,
  });

  JoinTripState copyWith({
    String? code,
    TripInvite? invite,
    bool clearInvite = false,
    bool? isLoading,
    bool? isJoining,
    bool? isJoined,
    String? joinedTripId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return JoinTripState(
      code: code ?? this.code,
      invite: clearInvite ? null : (invite ?? this.invite),
      isLoading: isLoading ?? this.isLoading,
      isJoining: isJoining ?? this.isJoining,
      isJoined: isJoined ?? this.isJoined,
      joinedTripId: joinedTripId ?? this.joinedTripId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class JoinTripController extends StateNotifier<JoinTripState> {
  final GroupSharingService _sharingService;

  JoinTripController({
    required GroupSharingService sharingService,
  })  : _sharingService = sharingService,
        super(const JoinTripState());

  /// Update input code (strips whitespace, capitalizes 6-char alphanumeric short codes
  /// while preserving case for full UUID tokens).
  /// If code reaches 6 characters or is a token format, automatically fetch preview.
  Future<void> updateCode(String rawCode) async {
    final trimmed = rawCode.trim();
    final sanitized =
        (!trimmed.contains('-') && trimmed.length <= 6) ? trimmed.toUpperCase() : trimmed;
    if (sanitized == state.code) return;

    state = state.copyWith(code: sanitized, clearInvite: true, clearError: true);

    if (sanitized.isEmpty) {
      return;
    }

    // Automatically check when 6 characters (short code) or longer (full token)
    if (sanitized.length == 6 || sanitized.length > 20) {
      await fetchPreview(sanitized);
    }
  }

  /// Manually or automatically fetch preview for token or code.
  Future<void> fetchPreview([String? tokenOrCode]) async {
    final target = (tokenOrCode ?? state.code).trim();
    if (target.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final invite = await _sharingService.getInvitePreview(target);
      if (!mounted) return;
      if (state.code != target) return;
      if (invite == null) {
        state = state.copyWith(
          isLoading: false,
          clearInvite: true,
          errorMessage: 'Invite not found or invalid code.',
        );
      } else if (!invite.isValid) {
        state = state.copyWith(
          isLoading: false,
          invite: invite,
          errorMessage: invite.isRevoked ? 'This invite has been revoked.' : 'This invite has expired.',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          invite: invite,
          clearError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        clearInvite: true,
        errorMessage: 'Failed to load invite: ${e.toString()}',
      );
    }
  }

  /// Execute join with the currently loaded invite preview.
  Future<TripMember?> joinTrip({
    String? displayName,
    String? avatarUrl,
    String? userEmail,
  }) async {
    final invite = state.invite;
    final tokenOrCode = invite?.token ?? state.code;
    if (tokenOrCode.isEmpty) {
      state = state.copyWith(errorMessage: 'No valid invite selected.');
      return null;
    }

    state = state.copyWith(isJoining: true, clearError: true);
    try {
      final member = await _sharingService.joinTripWithInvite(
        tokenOrCode,
        displayName: displayName,
        avatarUrl: avatarUrl,
        userEmail: userEmail,
      );
      if (!mounted) return member;

      state = state.copyWith(
        isJoining: false,
        isJoined: true,
        joinedTripId: member.tripId,
        clearError: true,
      );
      return member;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(
        isJoining: false,
        errorMessage: 'Failed to join trip: ${e.toString()}',
      );
      return null;
    }
  }

  /// Reset all state back to initial.
  void reset() {
    state = const JoinTripState();
  }
}

/// Provider for JoinTripController.
final joinTripControllerProvider =
    StateNotifierProvider.autoDispose<JoinTripController, JoinTripState>((ref) {
  final sharingService = ref.watch(groupSharingServiceProvider);
  return JoinTripController(sharingService: sharingService);
});
