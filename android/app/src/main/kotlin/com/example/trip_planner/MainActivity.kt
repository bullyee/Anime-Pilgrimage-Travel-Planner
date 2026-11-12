package com.example.trip_planner

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `trip_planner/overlay` channel. On Android the Anime Camera opens
 * the phone's own camera app (through image_picker, so shots get the phone's
 * full processing) and floats the anime reference over it in a small
 * draggable window, [ReferenceOverlay].
 *
 * The FlutterEngine is created here once per process and kept in
 * [FlutterEngineCache], not owned by the Activity: swiping the task away from
 * Recents destroys this Activity, but the engine (and the Dart isolate with
 * its frame uploads, see [TransferService]) carries on, and the next
 * MainActivity attaches to the same engine and shows its live state. Only
 * when the process dies does the next launch start a new engine.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "trip_planner/overlay"
    private var channel: MethodChannel? = null
    private var overlay: ReferenceOverlay? = null
    private val handler = Handler(Looper.getMainLooper())

    // Where the last window was when it closed, so the next round of the
    // same shot series (Take more) can put it back there at the same size.
    private var lastPlacement: ReferenceOverlay.Placement? = null

    // While the floating reference is up, show it only while the camera is on
    // screen: switching to another app hides it, coming back shows it again
    // where it was.
    private val followCamera = object : Runnable {
        override fun run() {
            val shown = overlay ?: return
            if (!shown.isShowing) {
                // Closed with the bar's ✕.
                lastPlacement = shown.lastPlacement ?: lastPlacement
                overlay = null
                return
            }
            shown.setShown(isCameraOnScreen())
            handler.postDelayed(this, CAMERA_POLL_MS)
        }
    }

    // Whether this Activity attached to an engine that was already running
    // Dart (the app was reopened while the process lived on).
    private var reusedEngine = false

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let {
            reusedEngine = it.dartExecutor.isExecutingDart
            return it
        }
        // Plugins register themselves (the constructor's default); the
        // Activity delegate runs the Dart entrypoint on first attach, with the
        // launch intent's deep link as the initial route.
        val engine = FlutterEngine(context.applicationContext)
        val messenger = engine.dartExecutor.binaryMessenger
        JpegEncoder.register(messenger)
        TransferBridge.register(messenger, context.applicationContext)
        cache.put(ENGINE_ID, engine)
        return engine
    }

    // The engine is the process's, not this Activity's.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A running engine has had its initial route; a link that opened this
        // new Activity (an invite) goes in as a new route instead, as when
        // the app is already open.
        val launch = intent
        if (reusedEngine && savedInstanceState == null && launch?.action == Intent.ACTION_VIEW && launch.data != null) {
            onNewIntent(launch)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TransferBridge.activity = this

        val overlayChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = overlayChannel
        overlayChannel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "requestPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }
                    "mayBeRestricted" -> result.success(mayBeRestricted())
                    "openAppInfo" -> {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
                        )
                        result.success(null)
                    }
                    "showOverlay" -> {
                        // One reference ("path"), or a spot's frames
                        // ("paths") to switch between, starting on "index".
                        val paths = call.argument<List<String>>("paths")
                            ?: listOfNotNull(call.argument<String>("path"))
                        val index = call.argument<Int>("index") ?: 0
                        val opacity = (call.argument<Double>("opacity") ?: 0.6).toFloat()
                        // False for the float-only mode: the window stays
                        // up while the user shoots with any camera app.
                        val follow = call.argument<Boolean>("followCamera") ?: true
                        // The next round of the same series: back where the
                        // last window was.
                        val keepPlacement = call.argument<Boolean>("keepPlacement") ?: false
                        when {
                            paths.isEmpty() ->
                                result.error("no_path", "path is required", null)
                            !canDrawOverlays() ->
                                result.error("no_permission", "overlay permission not granted", null)
                            else -> {
                                hideOverlay()
                                val shown = ReferenceOverlay(this) { frame ->
                                    channel?.invokeMethod("frameChanged", frame)
                                }
                                val placement = if (keepPlacement) lastPlacement else null
                                if (shown.show(paths, index, opacity, placement)) {
                                    overlay = shown
                                    if (follow) handler.post(followCamera)
                                    result.success(true)
                                } else {
                                    result.error("show_failed", "could not show the reference", null)
                                }
                            }
                        }
                    }
                    "hideOverlay" -> {
                        hideOverlay()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether the camera this app opened is what's on screen. It was opened
     * for a result, so it runs on top of this app's task: follow that task's
     * visibility. Android 13+ only reports it; on older versions, or if the
     * camera got a task of its own (this task's top is still us, hidden behind
     * it), keep the window up rather than hide it for good.
     */
    private fun isCameraOnScreen(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val activities = getSystemService(ActivityManager::class.java) ?: return true
        val task = activities.appTasks.asSequence()
            .mapNotNull { runCatching { it.taskInfo }.getOrNull() }
            .firstOrNull { it.taskId == taskId } ?: return true
        val cameraOnTop = task.topActivity?.packageName.let { it != null && it != packageName }
        return !cameraOnTop || task.isVisible
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    /**
     * Whether Android may refuse "Display over other apps" as a restricted
     * setting: from Android 13, an app installed from a downloaded APK rather
     * than an app store needs "Allow restricted settings" in its App info
     * first. Android doesn't say whether that was done, so this only tells
     * when it could apply: Android 13 or later and not installed by Google
     * Play.
     */
    private fun mayBeRestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
        val installer = try {
            packageManager.getInstallSourceInfo(packageName).installingPackageName
        } catch (e: Exception) {
            null
        }
        return installer != "com.android.vending"
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
    }

    private fun hideOverlay() {
        handler.removeCallbacks(followCamera)
        overlay?.let {
            it.hide()
            lastPlacement = it.lastPlacement ?: lastPlacement
        }
        overlay = null
    }

    // Called when this Activity lets go of the engine (it outlives us): drop
    // the handlers that point at this Activity.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        if (TransferBridge.activity === this) TransferBridge.activity = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }

    private companion object {
        const val CAMERA_POLL_MS = 500L
        const val ENGINE_ID = "trip_planner_main"
    }
}
