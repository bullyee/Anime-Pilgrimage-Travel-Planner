---
name: run-app
description: Launch and drive the trip_planner Flutter app on Android from this repo — boot the Pixel_Test emulator (or use a connected phone), build and install the APK, navigate with adb taps found via uiautomator, take screenshots, and read Flutter logs. Use when asked to run, launch, test on a device, reproduce a bug, or screenshot the app.
---

# Run trip_planner on Android

Verified 2026-10-29 on the Windows dev PC through Claude Code's Bash tool (Git Bash) while reproducing issue #57. If a step needs a workaround that isn't written here, fix this file.

## 0. Shell setup (every Bash call — state doesn't persist)

```bash
export MSYS_NO_PATHCONV=1   # otherwise Git Bash rewrites /sdcard/x into C:/Program Files/Git/sdcard/x
SDK="${ANDROID_HOME:-$(cygpath -u "$LOCALAPPDATA")/Android/Sdk}"
ADB="$SDK/platform-tools/adb.exe"   # adb is not on PATH on the dev PC
EMU="$SDK/emulator/emulator.exe"
APP=com.example.trip_planner
```

`flutter` is on PATH. On macOS/Linux drop `MSYS_NO_PATHCONV`, `cygpath` and the `.exe` suffixes.

With `MSYS_NO_PATHCONV=1`, *host* paths handed to `adb.exe` are no longer translated either: `adb install /c/Users/...` fails with "failed to stat" (and a `| tail -1` hides that). Pass host files as repo-relative paths or through `"$(cygpath -w "$path")"`. Redirections like `> "$file"` are done by bash and are fine.

## 1. Get a device

```bash
"$ADB" devices -l
```

- **Phone:** enable USB debugging and accept the PC's key prompt; it then lists as `device`.
- **No device:** boot the emulator. Both commands below must run with `run_in_background: true` — the Bash tool blocks foreground `sleep`, and the emulator never exits. Wait for the second one's completion notification.

```bash
"$EMU" -avd Pixel_Test -no-boot-anim -no-snapshot-save
```
```bash
"$ADB" wait-for-device; until [ "$("$ADB" shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done; "$ADB" devices -l
```

`Pixel_Test` is Android 15, x86_64, 1080×2400. List AVDs with `"$EMU" -list-avds`.

## 2. Build, install, launch

```bash
flutter build apk --debug          # ~2.5 min cold; run_in_background
"$ADB" install -r build/app/outputs/flutter-apk/app-debug.apk
"$ADB" logcat -c
"$ADB" shell monkey -p $APP -c android.intent.category.LAUNCHER 1
```

- Use the APK route rather than `flutter run`: `flutter run` is an interactive hot-reload console, awkward to drive from a tool. Logs come from logcat instead.
- `install -r` keeps app data (database, sign-in). For a clean slate: `"$ADB" shell pm clear $APP`.
- Release build: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`. It is debug-signed, so it installs over a debug build as long as its versionCode is not lower.
- **Low memory on the dev PC:** `android/gradle.properties` asks Gradle for an 8 GB heap, and Claude Code stops a background build when RAM runs low. Then build in the foreground with a capped heap and only the device's ABI (`android-arm64` for a phone, `android-x64` for Pixel_Test), about 2 min cold and 1 min warm, and stop Gradle afterwards. The APK lands in the same place:

  ```bash
  cd android && JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" ./gradlew --no-daemon \
    "-Dorg.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=768m" -Pkotlin.compiler.execution.strategy=in-process \
    -Ptarget-platform=android-arm64 assembleDebug
  JAVA_HOME="/c/Program Files/Android/Android Studio1/jbr" ./gradlew --stop
  ```
- A phone is someone's own device with their data on it: install onto it only when its owner says so, always with `install -r` (never uninstall or `pm clear`), and pass `-s <serial>` to every `adb` call when the emulator is also attached.
- A debug cold start shows the Flutter logo splash for ~10 s before the home screen. On a phone with 16 KB memory pages (Pixel 10a), a debug build also opens a system "16 KB" compatibility dialog at every cold start; tap OK (`確定` on a Chinese phone), not "Don't show again".
- **Check that `adb install` printed `Success`** (don't pipe it through `tail -1`); a failed install leaves the old build running and silently invalidates the test. The debug APK is ~200 MB and Pixel_Test's 6 GB `/data` fills up — "Requested internal only, but not enough space" means run `"$ADB" shell pm trim-caches 64G`, and if `df -h /data` still shows < ~1 GB free, test with the ~93 MB release APK instead.

## Scripted runs

For anything repeatable, write a flow instead of tapping by hand:
- `python -I ~/.claude/harness/uiflow.py tool/ui/flows/<flow>.json` runs one flow. It does the waits, taps, typing and screenshots, and checks logcat for Flutter exceptions. It writes a trajectory and report.html.
- `python -I ~/.claude/harness/uiflow.py --dump` lists the labels on screen.
- The `verify` skill runs every flow after a build.

The manual commands below are for exploring and for what flows can't do: the floating window, the camera app, pinch.

## 3. Look at the screen

```bash
ui() {   # visible widgets with their tap bounds
  "$ADB" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  "$ADB" shell cat /sdcard/ui.xml \
    | grep -o '\(content-desc\|text\)="[^"]\+"[^>]*bounds="[^"]*"' \
    | sed -E 's/ (resource-id|class|package|checkable|checked|clickable|enabled|focusable|focused|scrollable|long-clickable|password|selected|index|hint)="[^"]*"//g'
}
shot() { "$ADB" exec-out screencap -p > "$1"; }   # then Read the PNG
```

- Flutter exposes widgets through accessibility, so labels appear as `content-desc`, e.g. `content-desc="Library&#10;Your saved places, by anime, tag and region" bounds="[42,567][1038,798]"`. Tap the center of `bounds`.
- Some widgets are missing from the dump (speed-dial labels, dialog body text, snackbars on some frames). Take a screenshot and read coordinates off it; the Read tool shows it scaled and states the factor to multiply by.
- Save screenshots in the session scratchpad, never in the repo.
- To wait for something, poll `ui | grep -q "<label>"` in a loop of ~10 iterations (one dump takes ~1 s) instead of sleeping.

## 4. Interact

```bash
"$ADB" shell input tap X Y
"$ADB" shell input text "K-On"     # ASCII only; %s for a space
# Pixel_Test's Gboard (Zhuyin) can mangle `input text` ("Smoke Trip" -> "smoke"). uiflow.py
# switches the IME off for a run; by hand: ime disable com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
# ... then ime enable + ime set the same id afterwards.
"$ADB" shell input keyevent 4      # back
```

## 5. Logs

```bash
"$ADB" logcat -d -s flutter | tail -50                      # debugPrint / AppLogger
"$ADB" logcat -d | grep -iE "FATAL|AndroidRuntime" | tail
```

## Navigation map

Observed on Pixel_Test with a small database; positions move with content, so confirm with `ui` before tapping.

| Goal | Path (tap centers) |
|---|---|
| Home | Bottom bar **Trips** · **Shoot** (big middle button) · **Library**; app bar **More** (⋮). **Shoot** opens the "Shoot here" sheet (asks for location first; back closes it); **Library** pushes the library page (back returns). With no trips, the home card offers **Plan a trip** and **Import from Anitabi** (2026-11-11, Pixel_Test; `tool/ui/flows/smoke.json`) |
| New place | Library → **Add a place** (empty library) or the **Add place** FAB → type `lat,lng` in the search box (parsed on the device, no Nominatim call) and press Enter → Name (540,1544) → **Save to library** |
| Import from Anitabi | Library → **Import from Anitabi** (app bar, or the empty library's button) → search a title → tick spots → save. Confirm the labels with `ui`; the Anitabi rules in CLAUDE.md apply |
| New trip | **Plan a trip** (empty home) → My Trips → **New trip** → a sheet with the name field focused (placeholder "Kyoto pilgrimage"), Description, Start date **Decide later**, Days −/+ → **Create trip** → the trip page (Plan / Stops / Members tabs). Scripted in `tool/ui/flows/create_trip.json` |
| A stop's page | My Trips → a trip → **Stops** tab → **Add stops** → *From my library* → tick places → **Add N stops**; tap a stop to open its page |
| Anime Camera (Android) | Home **Anime Camera**, or a place or stop page's **Take photo** → place and frame sheets (a place with one frame skips the second) → the camera app opens with the frame in a floating window → shutter (540,2238) → ✓ (539,2242) → the camera opens again for the next shot; back (`keyevent 4`) in the camera ends the series → the pick screen: `Shot i of n` (swipe, or tap a thumbnail), tap the shot to keep it, **Keep N** saves, **Take more** reopens the camera, ✕ discards. On a Pixel 10a's Pixel Camera, shutter and ✓ are both at (540,1799) |
| Floating Reference (Android) | Home **Floating Reference**, or a place or stop page's **Float frame** → the window floats over every app until a double-tap; no camera opens |

## Anime Camera on Android

Android shoots with the phone's own camera app (`image_picker`) and floats the reference over it in a window drawn by `ReferenceOverlay.kt`.

```bash
"$ADB" shell appops set $APP SYSTEM_ALERT_WINDOW allow   # skip the "Display over other apps" settings detour
"$ADB" shell appops set $APP SYSTEM_ALERT_WINDOW deny    # test the permission dialog instead
win() { "$ADB" shell dumpsys window windows | grep -cE "Window #[0-9]+ Window\{[0-9a-f]+ u0 $APP\}:"; }   # 1 = floating window up
```

- The floating window never appears in a `ui` dump, so use `shot` for it. The emulator's Camera app doesn't either; a Pixel phone's Pixel Camera does, labelled in the phone's language (`拍照` shutter, `完成` done on a Chinese phone), so wait for the camera to reopen with `ui | grep -q 拍照`.
- The floating window starts in a top corner. In portrait that's top-right; in landscape it's top-left, clear of the shutter. Read its position off a screenshot: in the v0.1.3 smoke test it sat at about (564–1046, 390–658) on Pixel_Test.
- Tapping the window shows a −/+ bar underneath. It appears about 0.3 s after the tap, once the tap can't be a double-tap, then fades out 1.5 s after the last touch (0.15 s fade); another tap on the window hides it at once. Take the screenshot right after the tap.
- There is no close button: a double-tap closes the window, and the camera flow closes it by itself when the series ends.
- Drag the window with `input swipe`. After a rotation it must stay fully on screen.
- The system photo picker opens full-screen or as a half sheet, so photo positions change. Tap a photo by the bounds of its `Photo taken on …` entry in `ui`, not by fixed coordinates; a tap outside the sheet cancels the pick.
- `adb` can't fake a pinch; check resize on a phone. Separate `adb shell input tap` calls arrive too far apart for a double-tap, but two in one call do it: `"$ADB" shell "input tap X Y; input tap X Y"` closes the window (`win` goes to 0).
- adb round trips (and a host-side `shot`) take about a second, too slow to time the bar. Run a timed sequence on the device in one call and pull the screenshots afterwards: `"$ADB" shell "input tap X Y; sleep 0.6; input tap X Y; sleep 0.4; screencap -p /sdcard/b.png"`, then `"$ADB" exec-out cat /sdcard/b.png > b.png`.
- Between shots `win` stays 1; backing out of the camera ends the series and must leave it at 0.
- A series lives in `files/shot_series/<id>/` (its shots and `series.json`, picks included) until **Keep** or ✕: `"$ADB" shell run-as $APP ls files/shot_series`. Kept shots are copied to `app_flutter/camera_photos/` with a `photos` row, and to the gallery's `Pictures/Trip Planner/`.
- **Android killing the app mid-series:** `am kill` does nothing while the floating window is up, since the app counts as visible. On the camera's confirm screen, run `"$ADB" shell run-as $APP kill -9 $("$ADB" shell pidof $APP | tr -d '\r')` (the low-memory killer's signal), then tap ✓. The app should restart on the pick screen with the new shot added, the earlier picks kept, and the newest shot showing.
- Leaving the camera for another app (`input keyevent 3` for Home) hides the window. `win` stays 1, because the window is only made invisible, so check with `shot`. Returning through Recents shows it again in the same place.
- Reinstalling the app while the camera is open kills the app, and the window goes with it, so start the flow again.

## Gotchas

- **Never run `flutter analyze`** on the dev PC; it freezes the machine. `flutter test` is fine.
- `flutter test` / `flutter build` run `pub get`, which can rewrite the plugin registrants under `linux/`, `macos/`, `windows/` with line-ending-only changes. Check with `git diff --stat`, then `git restore -- linux macos windows`.
- **Anitabi rate rules:** the emulator shares the PC's public IP. Anitabi's Cloudflare temporarily blocks an IP that requests undocumented paths on `api.anitabi.cn`, and the block also covers `image.anitabi.cn`. A 403 "Sorry, you have been blocked" page means wait — don't retry in a loop and don't probe other paths. The import reads static data from `w.junreimap.com` and falls back to the `img-tc.anitabi.cn` image mirror, so it can still work from a blocked IP. Bangumi search (`api.bgm.tv`) is unaffected.
- The import caches Anitabi's map data under the app's support directory (`files/anitabi_static/`); inspect it with `"$ADB" shell run-as $APP ls files/anitabi_static`. Re-importing an anime queues covers only for newly added spots.
- Fresh machine: if the app dies with a dlopen or path-not-found error for a native library (sqlite3, firebase), the pub cache copy is incomplete. Delete that package's directory from the pub cache, then `flutter pub get`, `flutter clean`, and rebuild.
- The x86_64 emulator can't fully exercise the Anime Camera cutout (ONNX runtime ships arm64 only); use a phone for that.

## Report back

Say which device and build you ran (debug/release, branch, commit), what you drove, what you saw (with screenshots), and anything you could not verify.
