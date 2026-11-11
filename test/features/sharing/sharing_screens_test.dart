import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/sharing/invite_links.dart';
import 'package:trip_planner/features/sharing/models/trip_invite.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/sharing/screens/join_trip_screen.dart';
import 'package:trip_planner/features/sharing/services/group_sharing_service.dart';
import 'package:trip_planner/features/trip/screens/trip_members_tab.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';
import 'package:trip_planner/features/trip/widgets/trip_card.dart';

import 'fake_sharing_firestore.dart';

const _token = '8f3c41d2-5b6e-4a7f-9c0d-1e2f3a4b5c6d';

TripInvite _invite({
  TripMemberRole role = TripMemberRole.editor,
  bool revoked = false,
  Duration expiresIn = const Duration(days: 7),
}) =>
    TripInvite(
      token: _token,
      shortCode: 'K7MQ2P',
      tripId: 't1',
      role: role,
      createdBy: 'aki',
      inviterName: 'Aki',
      tripTitle: 'Kansai with friends',
      tripDates: '2026-11-20',
      stopCount: 12,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(expiresIn),
      isRevoked: revoked,
    );

TripMember _member(String id, String name, TripMemberRole role, {int minutes = 0}) => TripMember(
      userId: id,
      tripId: 't1',
      role: role,
      displayName: name,
      joinedAt: DateTime(2026, 11, 1).add(Duration(minutes: minutes)),
    );

/// The sharing backend without Firestore: canned members, invites and
/// previews, and a log of what the screens asked it to do.
class _FakeSharing extends GroupSharingService {
  _FakeSharing(this.db, {String userId = 'u1'})
      : super(firestore: FakeSharingFirestore(), db: db, currentUserId: userId);

  final AppDatabase db;
  final calls = <String>[];
  List<TripMember> members = [];
  List<TripInvite> invites = [];
  TripInvite? preview;
  Object? previewError;

  /// Who owned the trip when its invite was made.
  String? ownerAtCreate;

  @override
  Future<TripInvite> createInvite({
    required String tripId,
    required TripMemberRole role,
    String? inviterName,
    String? inviterAvatarUrl,
    List<String>? emailAllowlist,
  }) async {
    calls.add('create ${role.name} as $inviterName');
    ownerAtCreate = (await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull())?.ownerId;
    return _invite(role: role);
  }

  @override
  Stream<List<TripMember>> watchTripMembers(String tripId) => Stream.value(members);

  @override
  Stream<List<TripInvite>> watchTripInvites(String tripId) => Stream.value(invites);

  @override
  Future<void> updateMemberRole(String tripId, String memberUserId, TripMemberRole newRole) async =>
      calls.add('role $memberUserId ${newRole.name}');

  @override
  Future<void> removeMember(String tripId, String memberUserId) async => calls.add('remove $memberUserId');

  @override
  Future<void> transferOwnership(String tripId, String newOwnerId) async => calls.add('owner $newOwnerId');

  @override
  Future<void> revokeInvite(String token) async => calls.add('stop $token');

  @override
  Future<void> unshareTrip(String tripId) async => calls.add('unshare $tripId');

  @override
  Future<void> leaveTrip(String tripId) async => calls.add('leave $tripId');

  @override
  Future<TripInvite?> getInvitePreview(String tokenOrCode) async {
    calls.add('preview $tokenOrCode');
    if (previewError case final error?) throw error;
    return preview;
  }

  /// Joins, then brings the trip down the way the sync engine would.
  @override
  Future<TripMember> joinTripWithInvite(
    String tokenOrCode, {
    String? displayName,
    String? avatarUrl,
    String? userEmail,
  }) async {
    calls.add('join $tokenOrCode as $displayName');
    final invite = preview!;
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: invite.tripId,
          title: invite.tripTitle,
          ownerId: 'aki',
          sharing: const Value('group'),
        ));
    return TripMember(
      userId: super.currentUserId,
      tripId: invite.tripId,
      role: invite.role,
      displayName: displayName ?? '',
      joinedAt: DateTime.now(),
    );
  }
}

void main() {
  late AppDatabase db;
  late _FakeSharing sharing;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    sharing = _FakeSharing(db);
  });

  tearDown(() => db.close());

  Future<Trip> addTrip({String ownerId = 'u1', String sharingMode = 'private'}) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: 't1',
          title: 'Uji day trip',
          ownerId: ownerId,
          sharing: Value(sharingMode),
          startDate: const Value('2026-11-20'),
        ));
    return (db.select(db.trips)..where((t) => t.id.equals('t1'))).getSingle();
  }

  Future<void> pump(WidgetTester tester, RouterConfig<Object> router, {String userId = 'u1'}) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(userId),
        groupSharingServiceProvider.overrideWithValue(sharing),
        sharingProfileProvider.overrideWithValue((name: 'Bea', avatarUrl: null)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  GoRouter membersRouter(Trip trip) => GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => Scaffold(body: TripMembersTab(trip: trip))),
      ]);

  /// Lets drift close its streams before the test ends.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  group('Members tab', () {
    testWidgets('a private trip says what sharing sends, and its invite sheet makes an invite', (tester) async {
      final trip = await addTrip();
      await pump(tester, membersRouter(trip));

      expect(find.text('Plan this trip together'), findsOneWidget);
      expect(find.text('Shared with the trip'), findsOneWidget);
      expect(find.text('Only you'), findsOneWidget);

      await tester.tap(find.text('Invite people'));
      await tester.pumpAndSettle();
      expect(find.text('Invite to Uji day trip'), findsOneWidget);
      expect(find.textContaining("This is the trip's first invite"), findsOneWidget);

      await tester.tap(find.text('View only'));
      await tester.tap(find.text('Create invite'));
      await tester.pumpAndSettle();

      expect(sharing.calls, contains('create viewer as Bea'));
      expect(find.byWidgetPredicate((w) => w is SelectableText && w.data == 'K7M Q2P'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Can view'), findsOneWidget);

      await tester.tap(find.text('Stop this invite'));
      await tester.pumpAndSettle();
      expect(sharing.calls, contains('stop $_token'));
      expect(find.text('Invite to Uji day trip'), findsNothing);
      await done(tester);
    });

    testWidgets('a trip made before signing in becomes yours before its first invite', (tester) async {
      final trip = await addTrip(ownerId: guestUserId);
      await pump(tester, membersRouter(trip));

      await tester.tap(find.text('Invite people'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create invite'));
      await tester.pumpAndSettle();

      expect(sharing.calls, anyElement(startsWith('create ')));
      expect(sharing.ownerAtCreate, 'u1');
      await done(tester);
    });

    testWidgets("someone else's private copy has nothing to invite to", (tester) async {
      final trip = await addTrip(ownerId: 'aki');
      await pump(tester, membersRouter(trip));

      expect(find.text('Plan this trip together'), findsOneWidget);
      expect(find.text('Invite people'), findsNothing);
      await done(tester);
    });

    testWidgets('the owner sees who is in the trip and can change what each can do', (tester) async {
      final trip = await addTrip(sharingMode: 'group');
      sharing
        ..members = [
          _member('ren', 'Ren', TripMemberRole.viewer, minutes: 2),
          _member('u1', 'Bea', TripMemberRole.owner),
          _member('aki', 'Aki', TripMemberRole.editor, minutes: 1),
        ]
        ..invites = [_invite()];
      await pump(tester, membersRouter(trip));

      expect(find.text('3 people'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Can view'), findsOneWidget);
      expect(find.text('K7M Q2P'), findsOneWidget);
      // The owner first, then by when they joined.
      final names = tester.widgetList<Text>(find.descendant(of: find.byType(ListTile), matching: find.byType(Text)));
      expect(names.map((t) => t.data).where(['You', 'Aki', 'Ren'].contains), ['You', 'Aki', 'Ren']);

      await tester.tap(find.byTooltip('Change what Aki can do'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make view only'));
      await tester.pumpAndSettle();
      expect(sharing.calls, contains('role aki viewer'));

      await tester.tap(find.byTooltip('Change what Ren can do'));
      await tester.pumpAndSettle();
      expect(find.text('Allow editing'), findsOneWidget);
      await tester.tap(find.text('Remove from trip'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Ren from the trip?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(sharing.calls, contains('remove ren'));

      await tester.tap(find.byTooltip('Change what Aki can do'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make owner'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Make owner'));
      await tester.pumpAndSettle();
      expect(sharing.calls, contains('owner aki'));

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(sharing.calls, contains('stop $_token'));

      expect(find.text('Aki and Ren keep their own copy of the trip, as it is then. It just stops syncing.'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Stop sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Stop sharing Uji day trip?'), findsOneWidget);
      expect(find.text('Leave trip'), findsNothing, reason: 'the owner stops sharing instead');
      await tester.tap(find.widgetWithText(FilledButton, 'Stop sharing'));
      await tester.pumpAndSettle();
      expect(sharing.calls, containsAllInOrder(['stop $_token', 'unshare t1']));
      await done(tester);
    });

    testWidgets('a member who is not the owner can leave, after saying so', (tester) async {
      final trip = await addTrip(ownerId: 'aki', sharingMode: 'group');
      sharing.members = [
        _member('aki', 'Aki', TripMemberRole.owner),
        _member('u1', 'Bea', TripMemberRole.editor, minutes: 1),
      ];
      await pump(tester, membersRouter(trip));

      expect(find.text('Stop sharing'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Leave trip'));
      await tester.pumpAndSettle();
      expect(find.text('Leave Uji day trip?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(sharing.calls, isNot(contains('leave t1')));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Leave trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();
      expect(sharing.calls, contains('leave t1'));
      expect(find.text('You left Uji day trip. Your copy is still here.'), findsOneWidget);
      await done(tester);
    });

    testWidgets("a viewer sees who is in the trip but can't change it", (tester) async {
      final trip = await addTrip(ownerId: 'aki', sharingMode: 'group');
      sharing.members = [
        _member('aki', 'Aki', TripMemberRole.owner),
        _member('u1', 'Bea', TripMemberRole.viewer, minutes: 1),
      ];
      await pump(tester, membersRouter(trip));

      expect(find.text('2 people'), findsOneWidget);
      expect(find.text('Aki'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.byTooltip('Change what Aki can do'), findsNothing);
      expect(find.text('Invite'), findsNothing);
      expect(find.text('Stop sharing'), findsNothing);
      await done(tester);
    });
  });

  testWidgets("the trip page's invite button opens the invite sheet for the owner", (tester) async {
    await addTrip();
    await pump(
      tester,
      GoRouter(initialLocation: '/trips/t1', routes: [
        GoRoute(path: '/trips/:tripId', builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!)),
      ]),
    );

    await tester.tap(find.byTooltip('Invite people'));
    await tester.pumpAndSettle();

    expect(find.text('Invite to Uji day trip'), findsOneWidget);
    await done(tester);
  });

  group('Trip page by role', () {
    GoRouter tripRouter() => GoRouter(initialLocation: '/trips/t1', routes: [
          GoRoute(path: '/trips/:tripId', builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!)),
        ]);

    Future<List<String>> menuItems(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final items = tester
          .widgetList<PopupMenuItem<String>>(find.byWidgetPredicate((w) => w is PopupMenuItem<String>))
          .map((i) => i.value!)
          .toList();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      return items;
    }

    testWidgets('a viewer can look but not change the trip, and can leave it', (tester) async {
      await addTrip(ownerId: 'aki', sharingMode: 'group');
      sharing.members = [
        _member('aki', 'Aki', TripMemberRole.owner),
        _member('u1', 'Bea', TripMemberRole.viewer, minutes: 1),
      ];
      await pump(tester, tripRouter());

      expect(find.textContaining('View only'), findsOneWidget);
      expect(find.byTooltip('Invite people'), findsNothing);
      expect(await menuItems(tester), ['leave']);

      expect(find.byTooltip('Edit the plan'), findsNothing);

      await tester.tap(find.text('Stops'));
      await tester.pumpAndSettle();
      expect(find.text('Add stops'), findsNothing);
      expect(find.textContaining('once someone who can edit the trip adds them'), findsOneWidget);
      await done(tester);
    });

    testWidgets('an editor can change the trip and leave it, but not delete it for everyone', (tester) async {
      await addTrip(ownerId: 'aki', sharingMode: 'group');
      sharing.members = [
        _member('aki', 'Aki', TripMemberRole.owner),
        _member('u1', 'Bea', TripMemberRole.editor, minutes: 1),
      ];
      await pump(tester, tripRouter());

      expect(find.textContaining('View only'), findsNothing);
      expect(await menuItems(tester), ['edit', 'leave']);
      expect(find.byTooltip('Edit the plan'), findsOneWidget);
      await done(tester);
    });

    testWidgets("while your role is unknown, someone else's shared trip can't be changed", (tester) async {
      // Your own member record hasn't come down yet (or couldn't load), so a
      // viewer can't be told from an editor: no edit controls until it does.
      await addTrip(ownerId: 'aki', sharingMode: 'group');
      sharing.members = [_member('aki', 'Aki', TripMemberRole.owner)];
      await pump(tester, tripRouter());

      expect(find.textContaining('View only'), findsNothing, reason: "it isn't known to be view only either");
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byTooltip('Edit the plan'), findsNothing);
      await tester.tap(find.text('Stops'));
      await tester.pumpAndSettle();
      expect(find.text('Add stops'), findsNothing);
      await done(tester);
    });

    testWidgets('the owner can edit and delete the trip', (tester) async {
      await addTrip();
      await pump(tester, tripRouter());

      expect(await menuItems(tester), ['edit', 'delete']);
      await done(tester);
    });
  });

  group('Members on trip cards', () {
    test('the line names up to two others, then counts them', () {
      expect(membersLine([]), 'Only you so far');
      expect(membersLine(['Aki']), 'You and Aki');
      expect(membersLine(['Aki', 'Ren']), 'You, Aki and Ren');
      expect(membersLine(['Aki', 'Ren', 'Sora']), 'You and 3 others');
    });

    testWidgets("a shared trip's card shows the others, the owner first", (tester) async {
      await addTrip(sharingMode: 'group');
      sharing.members = [
        _member('ren', 'Ren', TripMemberRole.viewer, minutes: 2),
        _member('aki', 'Aki', TripMemberRole.owner),
        _member('u1', 'Bea', TripMemberRole.editor, minutes: 1),
      ];
      await pump(
        tester,
        GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: TripMembersLine(tripId: 't1')))]),
      );

      expect(find.text('You, Aki and Ren'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('B'), findsNothing, reason: 'your own face is left out');
      await done(tester);
    });

    testWidgets('without your own member record yet, it just says shared', (tester) async {
      await addTrip(sharingMode: 'group');
      await pump(
        tester,
        GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: TripMembersLine(tripId: 't1')))]),
      );

      expect(find.text('Shared'), findsOneWidget);
      await done(tester);
    });
  });

  group('Join screen', () {
    GoRouter joinRouter(String location) => GoRouter(initialLocation: location, routes: [
          GoRoute(path: '/join', builder: (_, s) => JoinTripScreen(invite: inviteFromQuery(s.uri.queryParameters))),
          GoRoute(path: '/trips', builder: (_, _) => const Scaffold(body: Text('my trips'))),
          GoRoute(path: '/trips/:tripId', builder: (_, s) => Scaffold(body: Text('trip ${s.pathParameters['tripId']}'))),
        ]);

    testWidgets('a code finds the trip, and joining opens it once it has come down', (tester) async {
      sharing.preview = _invite();
      await pump(tester, joinRouter('/join'));
      expect(find.text('Join a trip'), findsOneWidget);
      expect(find.text('Enter the code from your invite.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'k7mq2p');
      await tester.pumpAndSettle();

      expect(sharing.calls, contains('preview K7MQ2P'));
      expect(find.text('Aki invited you to edit'), findsOneWidget);
      expect(find.text('Kansai with friends'), findsOneWidget);
      expect(find.textContaining('12 stops'), findsOneWidget);

      await tester.tap(find.text('Join trip'));
      await tester.pumpAndSettle();

      expect(sharing.calls, contains('join $_token as Bea'));
      expect(find.text('trip t1'), findsOneWidget);
      await done(tester);
    });

    testWidgets('a pasted link opens its invite', (tester) async {
      sharing.preview = _invite();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': inviteShareText(_invite())};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pump(tester, joinRouter('/join'));

      await tester.tap(find.text('Paste an invite link'));
      await tester.pumpAndSettle();

      expect(sharing.calls, contains('preview $_token'));
      expect(find.text('Aki invited you to edit'), findsOneWidget);
      await done(tester);
    });

    testWidgets('an expired invite says so, and offers another code', (tester) async {
      sharing.preview = _invite(expiresIn: const Duration(days: -1));
      await pump(tester, joinRouter('/join?token=$_token'));

      expect(find.text('This invite has expired'), findsOneWidget);
      expect(find.text('Invites work for 7 days. Ask Aki for a new one.'), findsOneWidget);

      await tester.tap(find.text('Enter another code'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the code from your invite.'), findsOneWidget);
      await done(tester);
    });

    testWidgets('a stopped invite says someone stopped it', (tester) async {
      sharing.preview = _invite(revoked: true);
      await pump(tester, joinRouter('/join?token=$_token'));

      expect(find.text('This invite was stopped'), findsOneWidget);
      await done(tester);
    });

    testWidgets("an invite to a trip you're already in opens it", (tester) async {
      await addTrip(ownerId: 'aki', sharingMode: 'group');
      sharing.preview = _invite();
      await pump(tester, joinRouter('/join?token=$_token'));

      expect(find.text("You're already in this trip"), findsOneWidget);
      await tester.tap(find.text('Open trip'));
      await tester.pumpAndSettle();
      expect(find.text('trip t1'), findsOneWidget);
      expect(sharing.calls.where((c) => c.startsWith('join')), isEmpty);
      await done(tester);
    });

    testWidgets('signed out, it asks to sign in before joining', (tester) async {
      sharing.preview = _invite();
      await pump(tester, joinRouter('/join?token=$_token'), userId: guestUserId);

      expect(find.text('Sign in to join Kansai with friends'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Join trip'), findsNothing);
      await done(tester);
    });

    testWidgets('offline, it says so, and trying again finds the trip', (tester) async {
      sharing.previewError = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      await pump(tester, joinRouter('/join?token=$_token'));

      expect(find.text("You're offline"), findsOneWidget);

      sharing
        ..previewError = null
        ..preview = _invite();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Aki invited you to edit'), findsOneWidget);
      await done(tester);
    });

    testWidgets("a code nobody made says so under the field", (tester) async {
      await pump(tester, joinRouter('/join'));

      await tester.enterText(find.byType(TextField), 'ABC234');
      await tester.pumpAndSettle();

      expect(find.text('No invite matches this code or link. Check it and try again.'), findsOneWidget);
      await done(tester);
    });
  });
}
