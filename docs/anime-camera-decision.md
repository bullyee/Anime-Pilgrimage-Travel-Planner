# Anime Camera: how to shoot with the reference

**Date:** 2026-10-29
**Feature:** Take a pilgrimage photo while seeing the anime reference frame, then pass the shot to the photo editor and save it to a POI.

## Decision: system camera + small draggable floating window (Android)

| Platform | Camera |
|---|---|
| Android | The phone's own camera app (through `image_picker`), with the reference in a small floating window (`SYSTEM_ALERT_WINDOW`) |
| iOS | The in-app camera (`camera` plugin, `camera_screen.dart`), with the reference overlaid inside the app. iOS can't draw over another app |
| Desktop / web | No camera |

We weighed three approaches. Approach 3 won.

## 1. System camera + full-screen overlay with Lock / Adjust

[`anime_camera_studio`](https://github.com/bullyee/anime_camera_studio) takes this approach, and it was used on a real trip.

- The reference covers the whole screen at reduced opacity.
  - In **Adjust** mode, the reference takes touches so it can be dragged, pinched and rotated.
  - In **Lock** mode, touches pass through to the camera.
- 👍 Full phone-camera quality: the maker's HDR, night mode, white balance and processing. The overlay lines up with the whole viewfinder.
- 👎 You have to switch to Lock before you can press the shutter, and back to Adjust to move the reference. The volume key works as a shutter in either mode.
- ⚠️ On Android 12+, a touch that passes through another app's window is blocked unless that window's alpha is ≤ 0.8. Studio makes only the image view translucent, so the window itself stays opaque. It worked on the trip phone but hasn't been checked on other phones. Setting the window's `alpha` to 0.8 removes the risk.

## 2. Our own in-app camera (CameraX), like MiriaGo

[MiriaGo](https://github.com/BilyHurington/MiriaGo) (MIT) takes this approach. It has a CameraX platform view on Android (`NativeCameraPreviewView.kt`) and AVFoundation on iOS, and falls back to `camerawesome` only when those aren't available.

- Its quality settings beat the `camera` plugin:
  - `CAPTURE_MODE_MAXIMIZE_QUALITY`
  - the logical multi-camera, so zooming switches lenses
  - tap to focus and meter
  - a telephoto mode
  - captures cropped to the anime frame's aspect ratio
- It draws the reference inside the app, as an overlay, a split view or a pinned thumbnail. The overlay ignores touches; you line up by moving the phone, not the reference.
- 👍 The most integrated option. It needs no extra permission, every gesture is ours (tap to focus, drag the reference, a shutter button), and iOS is possible.
- 👎 Third-party apps generally don't get the maker's HDR, night mode or white balance, so photos land between the `camera` plugin and the phone's camera app. It also needs a lot of native code on two platforms.
- You can judge the quality ceiling without writing code: shoot the same scene with MiriaGo's APK (v2.0.0) and with the phone's camera app.

## 3. System camera + small draggable floating window (chosen)

A small window shows the reference on top of the phone's camera app. Only the window takes touches. The shutter, tap-to-focus and zoom everywhere else go straight to the camera, so there's no mode switch.

- It builds on the April prototype, `OverlayService.kt` (commits `7dc4e2f`, `3c3b2ce`, `3af0d82`): drag to move, pinch to resize with the aspect ratio locked, double-tap to close.
- 👍 Full phone-camera quality and no mode switch. The Android 12 touch rule doesn't apply, because no touch passes through the overlay.
- 👎 Android only.
- 👎 The window still blocks whatever it covers. The April TODO in `3c3b2ce` ("the overlay now blocks the image capture") was the window sitting over the shutter. To line up the whole frame, you enlarge the window over the viewfinder.
- Changes from the April prototype:
  - The Activity creates the window instead of a foreground service. That means no notification, and none of the foreground-service type and permissions that Android 14 requires (`FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`).
  - On Android 11+ the window goes through its own `WindowContext`. An Activity's configuration stays in the orientation the app was last shown in, so a window added through it was boxed into a portrait-sized strip when the phone was turned to landscape.
  - Capture goes through `image_picker`. If Android kills the app while the camera is open, `retrieveLostData()` recovers the photo.
  - The window starts small, near the top and away from the shutter. Tap it to show opacity −/+, which fades away soon after the last touch.
  - The window shows only while the camera is on screen. Switching to another app hides it; coming back shows it again in the same place and size. This works because the camera is opened for a result and so runs on top of the app's own task. That task's visibility is public only from Android 13 (`TaskInfo.isVisible()`); on older versions the window simply stays up.

## Floating reference only

A second Android entry point: the home card **Floating Reference**, or **Float reference** on a POI page. It floats the reference without opening a camera.

Unlike the camera flow, the window stays up when the user leaves Trip Planner. That lets them shoot as many photos as they like with any camera app, and then edit the keeper with the home screen's **Edit Photo** or the POI page's Add image. It stays until it's closed with a double-tap (the bar's ✕ was dropped on 2026-11-08, since the double-tap does the same).

**Edit Photo** follows anime_camera_studio's Edit:
- pick a photo, then go straight to the editor
- add a reference there, from a POI's references or the gallery
- the result goes to the phone's gallery, and to the POI's media when the reference came from one

`ACTION_IMAGE_CAPTURE` closes the camera after one shot, so the camera flow opens it again after every shot until the user backs out, then lets them pick the shots to keep (`shot_series_screen.dart`). The floating-only mode works with any camera app instead; the user then picks the keeper from the gallery.

## Deferred

Not built yet: sharing an image into the app to start the camera, picking the photo from the gallery in the Anime Camera sheet, and a Match Color upgrade.

## Sources
- April prototype: commits `7dc4e2f`, `3c3b2ce`, `3af0d82` in this repo.
- anime_camera_studio: `android/app/src/main/kotlin/com/animecamera/anime_camera_studio/MainActivity.kt`, `lib/camera/camera_flow.dart`.
- MiriaGo: `android/app/src/main/kotlin/app/miriago/miriago/NativeCameraPreviewView.kt`, `lib/camera_reference/`.
- Android 12 untrusted touch events: https://developer.android.com/about/versions/12/behavior-changes-all#untrusted-touch-events
