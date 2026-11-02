import urllib.request
import urllib.error
import json
import base64
import sys

def create_jwt(user_id):
    header = base64.urlsafe_b64encode(b'{"alg":"none","typ":"JWT"}').decode('utf-8').rstrip('=')
    payload = base64.urlsafe_b64encode(
        f'{{"sub":"{user_id}","user_id":"{user_id}","aud":"trip-planner-2775c","iss":"https://securetoken.google.com/trip-planner-2775c"}}'.encode('utf-8')
    ).decode('utf-8').rstrip('=')
    return f"{header}.{payload}."

BASE_URL = 'http://127.0.0.1:8080/v1/projects/trip-planner-2775c/databases/(default)/documents'

def api_request(method, path, data=None, user_id=None):
    url = f"{BASE_URL}/{path}"
    headers = {'Content-Type': 'application/json'}
    if user_id:
        headers['Authorization'] = f"Bearer {create_jwt(user_id)}"
    
    body = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')

def main():
    print("=== RUNNING FIRESTORE RULES V2 TEST SUITE ===")
    tests_passed = 0
    tests_total = 0

    def assert_status(desc, expected_code, actual_code):
        nonlocal tests_passed, tests_total
        tests_total += 1
        if actual_code == expected_code:
            print(f" [PASS] {desc}")
            tests_passed += 1
        else:
            print(f" [FAIL] {desc}: expected {expected_code}, got {actual_code}")
            sys.exit(1)

    # 1. Legacy trips writes are preserved for v0.1.x clients (tested in test_rules.py)

    # 2. tripsV2: Unauthenticated create must be denied
    v2_trip_data = {
        'fields': {
            'id': {'stringValue': 'trip_v2_1'},
            'title': {'stringValue': 'Kyoto Trip'},
            'ownerId': {'stringValue': 'alice'},
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

    print(f"\nALL {tests_passed}/{tests_total} FIRESTORE RULES TESTS PASSED!")

if __name__ == '__main__':
    main()
