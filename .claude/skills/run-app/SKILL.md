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
- A debug cold start shows the Flutter logo splash for ~10 s before the home screen.
- **Check that `adb install` printed `Success`** (don't pipe it through `tail -1`); a failed install leaves the old build running and silently invalidates the test. The debug APK is ~200 MB and Pixel_Test's 6 GB `/data` fills up — "Requested internal only, but not enough space" means run `"$ADB" shell pm trim-caches 64G`, and if `df -h /data` still shows < ~1 GB free, test with the ~93 MB release APK instead.

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

- Flutter exposes widgets through accessibility, so labels appear as `content-desc`, e.g. `content-desc="View POIs&#10;Browse and manage…" bounds="[42,567][1038,798]"`. Tap the center of `bounds`.
- Some widgets are missing from the dump (speed-dial labels, dialog body text, snackbars on some frames). Take a screenshot and read coordinates off it; the Read tool shows it scaled and states the factor to multiply by.
- Save screenshots in the session scratchpad, never in the repo.
- To wait for something, poll `ui | grep -q "<label>"` in a loop of ~10 iterations (one dump takes ~1 s) instead of sleeping.

## 4. Interact

```bash
"$ADB" shell input tap X Y
"$ADB" shell input text "K-On"     # ASCII only; %s for a space
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
| Home cards | View POIs (540,682) · Map (540,934) · My Trips (540,1176) · Trip Calendar (540,1417) · Anime Camera (540,1659) |
| Import from Bangumi | View POIs → **Add** FAB (964,2221) → *Import from Bangumi* (964,1224, not in the dump) → type a name → **Import** on a result → dialog **Import** (793,1385) → snackbar with the outcome |
| New POI / Region / Anime / Tag | View POIs → **Add** FAB → the matching speed-dial entry (screenshot for positions) |
| Anime Camera (Android) | Home **Anime Camera** (540,1659), or a POI page's **Take photo** → reference sheet (POI references / gallery / none) → the emulator's Camera app opens with the reference in a floating window → shutter (540,2238) → ✓ (539,2242) → photo editor (its AppBar's POI button shows "No POI" for a home-entry shot without a POI reference) |
| Floating Reference (Android) | Home **Floating Reference** (the card under Anime Camera), or a POI page's **Float reference** → reference sheet → the window floats over every app until ✕ or a double-tap; no camera opens |

## Anime Camera on Android

Android shoots with the phone's own camera app (`image_picker`) and floats the reference over it in a window drawn by `ReferenceOverlay.kt`.

```bash
"$ADB" shell appops set $APP SYSTEM_ALERT_WINDOW allow   # skip the "Display over other apps" settings detour
"$ADB" shell appops set $APP SYSTEM_ALERT_WINDOW deny    # test the permission dialog instead
win() { "$ADB" shell dumpsys window windows | grep -cE "Window #[0-9]+ Window\{[0-9a-f]+ u0 $APP\}:"; }   # 1 = floating window up
```

- `ui` only dumps the top app's window. The camera app and the floating window don't appear in it, so use `shot` for both.
- The floating window starts in a top corner. In portrait that's top-right; in landscape it's top-left, clear of the shutter. Read its position off a screenshot: in the v0.1.3 smoke test it sat at about (564–1046, 390–658) on Pixel_Test.
- Tapping the window shows a −/+/✕ bar underneath, with ✕ around (967,716) in portrait.
  - The bar appears about 0.3 s after the tap, once the tap can't be a double-tap, and hides itself after 3 s. Take the screenshot right after the tap.
  - To close the window, run another command (a `shot`) between tapping the window and tapping ✕. Otherwise ✕ is tapped before the bar exists.
- Drag the window with `input swipe`. After a rotation it must stay fully on screen.
- The system photo picker opens full-screen or as a half sheet, so photo positions change. Tap a photo by the bounds of its `Photo taken on …` entry in `ui`, not by fixed coordinates; a tap outside the sheet cancels the pick.
- `adb` can't fake a pinch, and two `input tap` calls arrive too far apart for a double-tap. Check resize and double-tap-to-close on a phone.
- Backing out of the camera, or accepting a shot, must leave `win` at 0.
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
