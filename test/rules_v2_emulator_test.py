import urllib.request
import urllib.error
import json
import base64
import sys
import time

def create_jwt(user_id, email=None):
    header = base64.urlsafe_b64encode(b'{"alg":"none","typ":"JWT"}').decode('utf-8').rstrip('=')
    email_field = f',"email":"{email}"' if email else ''
    payload = base64.urlsafe_b64encode(
        f'{{"sub":"{user_id}","user_id":"{user_id}","aud":"trip-planner-2775c","iss":"https://securetoken.google.com/trip-planner-2775c"{email_field}}}'.encode('utf-8')
    ).decode('utf-8').rstrip('=')
    return f"{header}.{payload}."

BASE_URL = 'http://127.0.0.1:8080/v1/projects/trip-planner-2775c/databases/(default)/documents'

def api_request(method, path, data=None, user_id=None, email=None):
    url = f"{BASE_URL}{path}" if path.startswith(':') else f"{BASE_URL}/{path}"
    headers = {'Content-Type': 'application/json'}
    if user_id:
        headers['Authorization'] = f"Bearer {create_jwt(user_id, email=email)}"
    
    body = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')

def main():
    print("=== RUNNING FIRESTORE RULES V2 & STAGE 4 RBAC TEST SUITE ===")
    tests_passed = 0
    tests_total = 0

    def assert_status(desc, expected_code, actual_code, resp=None):
        nonlocal tests_passed, tests_total
        tests_total += 1
        if actual_code == expected_code:
            print(f" [PASS] {desc}")
            tests_passed += 1
        else:
            print(f" [FAIL] {desc}: expected {expected_code}, got {actual_code}")
            if resp:
                print(f"   Response: {resp}")
            sys.exit(1)

    # 1. Legacy trips writes are denied (read-only mode in schema v13)
    legacy_trip_data = {
        'fields': {
            'id': {'stringValue': 'legacy_trip_1'},
            'authorId': {'stringValue': 'alice'},
            'members': {'arrayValue': {'values': [{'stringValue': 'alice'}]}},
        }
    }
    code, _ = api_request('POST', 'trips?documentId=legacy_trip_1', legacy_trip_data, user_id='alice')
    assert_status("Legacy trips: Create is denied in v13 (403)", 403, code)

    code, _ = api_request('PATCH', 'trips/legacy_trip_1', legacy_trip_data, user_id='alice')
    assert_status("Legacy trips: Update is denied in v13 (403)", 403, code)

    code, _ = api_request('DELETE', 'trips/legacy_trip_1', user_id='alice')
    assert_status("Legacy trips: Delete is denied in v13 (403)", 403, code)

    time_chunk_data = {'fields': {'id': {'stringValue': 'chunk_1'}}}
    code, _ = api_request('POST', 'trips/legacy_trip_1/timeChunks?documentId=chunk_1', time_chunk_data, user_id='alice')
    assert_status("Legacy timeChunks: Create is denied in v13 (403)", 403, code)

    poi_data = {'fields': {'id': {'stringValue': 'poi_1'}}}
    code, _ = api_request('POST', 'trips/legacy_trip_1/pois?documentId=poi_1', poi_data, user_id='alice')
    assert_status("Legacy pois: Create is denied in v13 (403)", 403, code)

    # 2. tripsV2: Unauthenticated create must be denied
    v2_trip_data = {
        'fields': {
            'id': {'stringValue': 'trip_v2_1'},
            'title': {'stringValue': 'Kyoto Trip'},
            'ownerId': {'stringValue': 'alice'},
            'sharing': {'stringValue': 'group'},
            'members': {'arrayValue': {'values': [{'stringValue': 'alice'}]}},
            'dayCount': {'integerValue': '3'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2?documentId=trip_v2_1', v2_trip_data, user_id=None)
    assert_status("tripsV2: Unauthenticated create denied (403)", 403, code)

    # 3. tripsV2: Owner create with owner listed in members succeeds
    code, _ = api_request('POST', 'tripsV2?documentId=trip_v2_1', v2_trip_data, user_id='alice')
    assert_status("tripsV2: Authenticated owner create succeeds (200)", 200, code)

    # 4. tripsV2: Non-member reading trip denied
    code, _ = api_request('GET', 'tripsV2/trip_v2_1', user_id='intruder_bob')
    assert_status("tripsV2: Non-member read denied (403)", 403, code)

    # 5. tripsV2: Member reading trip succeeds
    code, _ = api_request('GET', 'tripsV2/trip_v2_1', user_id='alice')
    assert_status("tripsV2: Member read succeeds (200)", 200, code)

    # 6. tripsV2: Direct hard delete denied
    code, _ = api_request('DELETE', 'tripsV2/trip_v2_1', user_id='alice')
    assert_status("tripsV2: Direct delete denied (403)", 403, code)

    # 7. tripsV2: Member creating day block succeeds
    day_data = {
        'fields': {
            'id': {'stringValue': 'day_1'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'sortKey': {'stringValue': 'a0'},
            'title': {'stringValue': 'Day 1 Arashiyama'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/days?documentId=day_1', day_data, user_id='alice')
    assert_status("tripsV2/days: Member create day block succeeds (200)", 200, code)

    # 8. tripsV2: Non-member creating day block denied
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/days?documentId=day_2', day_data, user_id='intruder_bob')
    assert_status("tripsV2/days: Non-member create day block denied (403)", 403, code)

    # 9. tripsV2: Member creating stop succeeds
    stop_data = {
        'fields': {
            'id': {'stringValue': 'stop_1'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'placeKey': {'stringValue': 'anitabi:42'},
            'name': {'stringValue': 'Toyosato School'},
            'addedBy': {'stringValue': 'alice'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/stops?documentId=stop_1', stop_data, user_id='alice')
    assert_status("tripsV2/stops: Member create stop succeeds (200)", 200, code)

    # 9b. tripsV2: Member creating stop with valid note (<= 2000 chars) succeeds (200)
    stop_with_note = {
        'fields': {
            'id': {'stringValue': 'stop_note_valid'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'placeKey': {'stringValue': 'anitabi:42'},
            'name': {'stringValue': 'Toyosato School with Note'},
            'note': {'stringValue': 'Meet at 09:00 AM at the gate'},
            'addedBy': {'stringValue': 'alice'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/stops?documentId=stop_note_valid', stop_with_note, user_id='alice')
    assert_status("tripsV2/stops: Stop with valid note succeeds (200)", 200, code)

    # 9c. tripsV2: Stop with oversized note (> 2000 chars) denied (403)
    stop_oversized_note = {
        'fields': {
            'id': {'stringValue': 'stop_note_invalid'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'placeKey': {'stringValue': 'anitabi:42'},
            'name': {'stringValue': 'Oversized Note Stop'},
            'note': {'stringValue': 'x' * 2001},
            'addedBy': {'stringValue': 'alice'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/stops?documentId=stop_note_invalid', stop_oversized_note, user_id='alice')
    assert_status("tripsV2/stops: Stop with oversized note > 2000 chars denied (403)", 403, code)

    # 10. tripsV2: Member creating schedule item succeeds
    item_data = {
        'fields': {
            'id': {'stringValue': 'item_1'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'stopId': {'stringValue': 'stop_1'},
            'dayId': {'stringValue': 'day_1'},
            'sortKey': {'stringValue': 'a0'},
            'stayMinutes': {'integerValue': '60'},
            'transitMinutes': {'integerValue': '15'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/schedule_items?documentId=item_1', item_data, user_id='alice')
    assert_status("tripsV2/schedule_items: Member create item succeeds (200)", 200, code)

    # 11. tripsV2: Direct delete on subcollection denied
    code, _ = api_request('DELETE', 'tripsV2/trip_v2_1/stops/stop_1', user_id='alice')
    assert_status("tripsV2/stops: Direct delete denied (403)", 403, code)

    # 12. tripsV2: LWW update with newer timestamp succeeds
    update_data = {
        'fields': {
            'id': {'stringValue': 'stop_1'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'placeKey': {'stringValue': 'anitabi:42'},
            'name': {'stringValue': 'Toyosato School Renovated'},
            'addedBy': {'stringValue': 'alice'},
            'updatedAt': {'integerValue': '2000'}, # Newer
        }
    }
    code, _ = api_request('PATCH', 'tripsV2/trip_v2_1/stops/stop_1', update_data, user_id='alice')
    assert_status("tripsV2: LWW newer update succeeds (200)", 200, code)

    # 13. tripsV2: LWW update with older timestamp denied
    stale_update_data = {
        'fields': {
            'id': {'stringValue': 'stop_1'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'placeKey': {'stringValue': 'anitabi:42'},
            'name': {'stringValue': 'Toyosato School Stale'},
            'addedBy': {'stringValue': 'alice'},
            'updatedAt': {'integerValue': '500'}, # Older than 2000
        }
    }
    code, _ = api_request('PATCH', 'tripsV2/trip_v2_1/stops/stop_1', stale_update_data, user_id='alice')
    assert_status("tripsV2: LWW stale update denied (403)", 403, code)

    # =========================================================================
    # STAGE 4 RBAC & INVITE TESTS
    # =========================================================================
    print("\n--- Testing Stage 4 RBAC & Invites ---")

    # 14. Owner adds self as member doc under tripsV2/{tripId}/members/{ownerUid}
    alice_member_data = {
        'fields': {
            'userId': {'stringValue': 'alice'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'owner'},
            'displayName': {'stringValue': 'Alice'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/members?documentId=alice', alice_member_data, user_id='alice')
    assert_status("Stage 4: Owner can add self as owner member (200)", 200, code)

    # 15. Owner creates an invite for role 'viewer'
    now_epoch = int(time.time())
    expires_in_7_days = now_epoch + 7 * 86400
    invite_token = 'token_viewer_abc'
    invite_data = {
        'fields': {
            'token': {'stringValue': invite_token},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'viewer'},
            'createdBy': {'stringValue': 'alice'},
            'isRevoked': {'booleanValue': False},
            'expiresAt': {'timestampValue': f'{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(expires_in_7_days))}'},
            'tripTitle': {'stringValue': 'Kyoto Pilgrimage'},
        }
    }
    code, _ = api_request('POST', f'invites?documentId={invite_token}', invite_data, user_id='alice')
    assert_status("Stage 4: Owner can create invite (200)", 200, code)

    # 15b. Non-member intruder CANNOT forge an invite for trip_v2_1
    forged_invite = {
        'fields': {
            'token': {'stringValue': 'forged_token'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'editor'},
            'createdBy': {'stringValue': 'intruder_bob'},
            'isRevoked': {'booleanValue': False},
            'expiresAt': {'timestampValue': f'{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(expires_in_7_days))}'},
        }
    }
    code, _ = api_request('POST', 'invites?documentId=forged_token', forged_invite, user_id='intruder_bob')
    assert_status("Stage 4: Non-member cannot create invite for trip (403)", 403, code)

    # 16. Unauthenticated or outsider can read exact invite preview by token, but cannot list all invites
    code, resp = api_request('GET', f'invites/{invite_token}', user_id='charlie')
    assert_status("Stage 4: Any user can read invite preview by token (200)", 200, code)
    code, _ = api_request('GET', 'invites', user_id='charlie')
    assert_status("Stage 4: Listing all invites is denied (403)", 403, code)

    # 17. Charlie joins trip using the invite token to become 'viewer'
    charlie_member_data = {
        'fields': {
            'userId': {'stringValue': 'charlie'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'viewer'},
            'inviteToken': {'stringValue': invite_token},
            'displayName': {'stringValue': 'Charlie'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/members?documentId=charlie', charlie_member_data, user_id='charlie')
    assert_status("Stage 4: Charlie joins via valid invite token (200)", 200, code)

    # 18. Charlie as 'viewer' can read trip stops
    code, _ = api_request('GET', 'tripsV2/trip_v2_1/stops/stop_1', user_id='charlie')
    assert_status("Stage 4: Charlie (viewer) can read stops (200)", 200, code)

    # 19. Charlie as 'viewer' ATTEMPTS to create a new stop -> MUST BE DENIED (403)
    viewer_stop_data = {
        'fields': {
            'id': {'stringValue': 'stop_viewer_forbidden'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'placeKey': {'stringValue': 'anitabi:999'},
            'name': {'stringValue': 'Viewer Cannot Add'},
            'addedBy': {'stringValue': 'charlie'},
            'updatedAt': {'integerValue': '3000'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/stops?documentId=stop_viewer_forbidden', viewer_stop_data, user_id='charlie')
    assert_status("Stage 4: Charlie (viewer) cannot create stop (403)", 403, code)

    # 20. Alice (Owner) promotes Charlie to 'editor'
    promote_charlie_data = {
        'fields': {
            'userId': {'stringValue': 'charlie'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'editor'},
            'displayName': {'stringValue': 'Charlie'},
        }
    }
    code, _ = api_request('PATCH', 'tripsV2/trip_v2_1/members/charlie', promote_charlie_data, user_id='alice')
    assert_status("Stage 4: Owner can promote member to editor (200)", 200, code)

    # 21. Now as 'editor', Charlie creates a stop -> SUCCEEDS (200)
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/stops?documentId=stop_viewer_forbidden', viewer_stop_data, user_id='charlie')
    assert_status("Stage 4: Charlie (promoted to editor) can create stop (200)", 200, code)

    # 22. Charlie as editor tries to kick Alice (Owner) -> MUST BE DENIED (403)
    code, _ = api_request('DELETE', 'tripsV2/trip_v2_1/members/alice', user_id='charlie')
    assert_status("Stage 4: Non-owner cannot kick owner (403)", 403, code)

    # 23. Alice revokes the invite token
    revoke_data = {
        'fields': {
            'token': {'stringValue': invite_token},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'viewer'},
            'createdBy': {'stringValue': 'alice'},
            'isRevoked': {'booleanValue': True},
        }
    }
    code, _ = api_request('PATCH', f'invites/{invite_token}?updateMask.fieldPaths=isRevoked', revoke_data, user_id='alice')
    assert_status("Stage 4: Owner can revoke invite (200)", 200, code)

    # 24. New user David tries to join with revoked invite -> MUST BE DENIED (403)
    david_member_data = {
        'fields': {
            'userId': {'stringValue': 'david'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'viewer'},
            'inviteToken': {'stringValue': invite_token},
            'displayName': {'stringValue': 'David'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_v2_1/members?documentId=david', david_member_data, user_id='david')
    assert_status("Stage 4: Join with revoked invite denied (403)", 403, code)

    # 25. Charlie leaves trip (self-delete from members) -> SUCCEEDS (200)
    code, _ = api_request('DELETE', 'tripsV2/trip_v2_1/members/charlie', user_id='charlie')
    assert_status("Stage 4: Non-owner member can leave trip (200)", 200, code)

    # 26. Alice (sole owner) tries to self-delete from members -> DENIED (403)
    code, _ = api_request('DELETE', 'tripsV2/trip_v2_1/members/alice', user_id='alice')
    assert_status("Stage 4: Owner cannot leave without transferring ownership (403)", 403, code)

    # 27. Invite with > 7 days expiry is denied (403)
    expires_in_30_days = int(time.time() + 30 * 86400)
    invalid_expiry_invite = {
        'fields': {
            'token': {'stringValue': 'token_long_expiry'},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'viewer'},
            'createdBy': {'stringValue': 'alice'},
            'isRevoked': {'booleanValue': False},
            'expiresAt': {'timestampValue': f'{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(expires_in_30_days))}'},
        }
    }
    code, _ = api_request('POST', 'invites?documentId=token_long_expiry', invalid_expiry_invite, user_id='alice')
    assert_status("Stage 4: Invite with expiry > 7 days is denied (403)", 403, code)

    # 28. Short code create pointing to existing valid invite succeeds (200)
    code_data = {
        'fields': {
            'token': {'stringValue': invite_token},
        }
    }
    code, _ = api_request('POST', 'invite_codes?documentId=CODE42', code_data, user_id='alice')
    assert_status("Stage 4: Short code create pointing to owned invite succeeds (200)", 200, code)

    # 29. Short code delete by non-owner intruder is denied (403)
    code, _ = api_request('DELETE', 'invite_codes/CODE42', user_id='intruder_bob')
    assert_status("Stage 4: Intruder cannot delete short code (403)", 403, code)

    # 30. Short code delete by owner succeeds (200)
    code, _ = api_request('DELETE', 'invite_codes/CODE42', user_id='alice')
    assert_status("Stage 4: Owner can delete short code (200)", 200, code)

    # 31. Alice unshares trip to private -> former members cannot read trip (403)
    unshare_patch = {
        'fields': {
            'sharing': {'stringValue': 'private'},
            'members': {'arrayValue': {'values': [{'stringValue': 'alice'}]}},
            'updatedAt': {'integerValue': '5000'},
        }
    }
    code, _ = api_request('PATCH', 'tripsV2/trip_v2_1?updateMask.fieldPaths=sharing&updateMask.fieldPaths=members&updateMask.fieldPaths=updatedAt', unshare_patch, user_id='alice')
    assert_status("Stage 4: Owner can unshare trip (200)", 200, code)

    # 32. Charlie (former member) reads unshared trip -> DENIED (403)
    code, _ = api_request('GET', 'tripsV2/trip_v2_1', user_id='charlie')
    assert_status("Stage 4: Former member cannot read unshared private trip (403)", 403, code)

    # 33. Repro H: Editor attempts to take over trip ownership (patch ownerId) -> DENIED (403)
    takeover_patch = {
        'fields': {
            'ownerId': {'stringValue': 'charlie'},
            'updatedAt': {'integerValue': '6000'},
        }
    }
    code, _ = api_request('PATCH', 'tripsV2/trip_v2_1?updateMask.fieldPaths=ownerId&updateMask.fieldPaths=updatedAt', takeover_patch, user_id='charlie')
    assert_status("Stage 4 (Repro H): Editor cannot take over trip ownership (403)", 403, code)

    # 34. Repro I: Invite expiry update > 7 days is denied (403)
    far_future_expiry = int(time.time() + 365 * 86400)
    extend_invite_patch = {
        'fields': {
            'token': {'stringValue': invite_token},
            'tripId': {'stringValue': 'trip_v2_1'},
            'role': {'stringValue': 'viewer'},
            'createdBy': {'stringValue': 'alice'},
            'expiresAt': {'timestampValue': f'{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(far_future_expiry))}'},
        }
    }
    code, _ = api_request('PATCH', f'invites/{invite_token}?updateMask.fieldPaths=expiresAt', extend_invite_patch, user_id='alice')
    assert_status("Stage 4 (Repro I): Invite expiry update > 7 days is denied (403)", 403, code)

    # 35. Repro G: Removed editor rejoins with own invite is denied (403)
    trip_g_data = {
        'fields': {
            'id': {'stringValue': 'trip_g1'},
            'title': {'stringValue': 'Trip G'},
            'ownerId': {'stringValue': 'alice'},
            'sharing': {'stringValue': 'group'},
            'members': {'arrayValue': {'values': [{'stringValue': 'alice'}]}},
            'dayCount': {'integerValue': '1'},
            'updatedAt': {'integerValue': '1000'},
        }
    }
    api_request('POST', 'tripsV2?documentId=trip_g1', trip_g_data, user_id='alice')
    alice_member = {
        'fields': {
            'userId': {'stringValue': 'alice'},
            'tripId': {'stringValue': 'trip_g1'},
            'role': {'stringValue': 'owner'},
            'displayName': {'stringValue': 'Alice'},
        }
    }
    api_request('POST', 'tripsV2/trip_g1/members?documentId=alice', alice_member, user_id='alice')

    # Alice creates editor invite for Bob
    g_invite_token = 'token_g_edit'
    g_invite = {
        'fields': {
            'token': {'stringValue': g_invite_token},
            'tripId': {'stringValue': 'trip_g1'},
            'role': {'stringValue': 'editor'},
            'createdBy': {'stringValue': 'alice'},
            'isRevoked': {'booleanValue': False},
            'expiresAt': {'timestampValue': f'{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(int(time.time() + 86400)))}'},
        }
    }
    api_request('POST', f'invites?documentId={g_invite_token}', g_invite, user_id='alice')

    # Bob joins as editor
    bob_member = {
        'fields': {
            'userId': {'stringValue': 'bob'},
            'tripId': {'stringValue': 'trip_g1'},
            'role': {'stringValue': 'editor'},
            'inviteToken': {'stringValue': g_invite_token},
            'displayName': {'stringValue': 'Bob'},
        }
    }
    api_request('POST', 'tripsV2/trip_g1/members?documentId=bob', bob_member, user_id='bob')

    # Bob creates his own invite
    bob_invite_token = 'token_g_bob'
    bob_invite = {
        'fields': {
            'token': {'stringValue': bob_invite_token},
            'tripId': {'stringValue': 'trip_g1'},
            'role': {'stringValue': 'editor'},
            'createdBy': {'stringValue': 'bob'},
            'isRevoked': {'booleanValue': False},
            'expiresAt': {'timestampValue': f'{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(int(time.time() + 86400)))}'},
        }
    }
    api_request('POST', f'invites?documentId={bob_invite_token}', bob_invite, user_id='bob')

    # Alice removes Bob
    api_request('DELETE', 'tripsV2/trip_g1/members/bob', user_id='alice')

    # Bob attempts to rejoin using the invite he created -> MUST BE DENIED (403)
    bob_rejoin = {
        'fields': {
            'userId': {'stringValue': 'bob'},
            'tripId': {'stringValue': 'trip_g1'},
            'role': {'stringValue': 'editor'},
            'inviteToken': {'stringValue': bob_invite_token},
            'displayName': {'stringValue': 'Bob'},
        }
    }
    code, _ = api_request('POST', 'tripsV2/trip_g1/members?documentId=bob', bob_rejoin, user_id='bob')
    assert_status("Stage 4 (Repro G): Removed editor cannot rejoin with own invite (403)", 403, code)

    # 44. tripsV2 query (Issue #89): structuredQuery with members array-contains
    def run_trip_query(member_uid, user_id=None):
        q = {
            'structuredQuery': {
                'from': [{'collectionId': 'tripsV2'}],
            }
        }
        if member_uid is not None:
            q['structuredQuery']['where'] = {
                'fieldFilter': {
                    'field': {'fieldPath': 'members'},
                    'op': 'ARRAY_CONTAINS',
                    'value': {'stringValue': member_uid}
                }
            }
        return api_request('POST', ':runQuery', q, user_id=user_id)

    # alice queries for herself (has trips) -> 200
    code, resp = run_trip_query('alice', user_id='alice')
    assert_status("tripsV2 query: Alice querying own trips succeeds (200)", 200, code, resp=resp)

    # charlie queries for himself (has no trips) -> 200
    code, resp = run_trip_query('charlie', user_id='charlie')
    assert_status("tripsV2 query: Charlie querying own empty trips succeeds (200)", 200, code, resp=resp)

    # intruder_bob querying for alice's trips -> 403
    code, resp = run_trip_query('alice', user_id='intruder_bob')
    assert_status("tripsV2 query: Intruder querying another user's trips denied (403)", 403, code, resp=resp)

    # unauthenticated query -> 403
    code, resp = run_trip_query('alice', user_id=None)
    assert_status("tripsV2 query: Unauthenticated query denied (403)", 403, code, resp=resp)

    # unconstrained query (all trips without members filter) -> 403
    code, resp = run_trip_query(None, user_id='alice')
    assert_status("tripsV2 query: Unconstrained query without members filter denied (403)", 403, code, resp=resp)

    print(f"\nALL {tests_passed}/{tests_total} FIRESTORE RULES TESTS PASSED!")

if __name__ == '__main__':
    main()
