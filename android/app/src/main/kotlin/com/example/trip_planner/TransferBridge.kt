package com.example.trip_planner

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * The `trip_planner/transfers` channel between the Dart transfer queue
 * (`transfer_foreground_service.dart`) and [TransferService].
 *
 * Registered once on the cached FlutterEngine, with the application context,
 * so it keeps working while no Activity is attached (screen off, another app,
 * or the task swiped away). Only the notification-permission prompt needs an
 * Activity; [MainActivity] sets [activity] while it is attached.
 *
 * Dart → Kotlin: `start`, `update`, `stop`, `clearDone`,
 * `requestNotificationPermission`, `isUnmeteredNetwork`.
 * Kotlin → Dart: `cancel` (the notification's Cancel action).
 */
object TransferBridge {
    private const val CHANNEL = "trip_planner/transfers"
    private const val NOTIFICATION_PERMISSION_REQUEST = 4103

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activityRef: WeakReference<Activity>? = null
    private val main = Handler(Looper.getMainLooper())

    var activity: Activity?
        get() = activityRef?.get()
        set(value) {
            activityRef = value?.let { WeakReference(it) }
        }

    fun register(messenger: BinaryMessenger, context: Context) {
        appContext = context.applicationContext
        val ch = MethodChannel(messenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            val ctx = appContext
            if (ctx == null) {
                result.error("no_context", "transfer bridge not ready", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "start" -> result.success(TransferService.start(ctx, progressFrom(call.arguments)))
                "update" -> {
                    TransferService.update(ctx, progressFrom(call.arguments))
                    result.success(null)
                }
                "stop" -> {
                    TransferService.stop(ctx, call.argument<String>("title"), call.argument<String>("text"))
                    result.success(null)
                }
                "clearDone" -> {
                    TransferService.clearDone(ctx)
                    result.success(null)
                }
                "requestNotificationPermission" -> result.success(requestNotificationPermission(ctx))
                "isUnmeteredNetwork" -> result.success(isUnmetered(ctx))
                else -> result.notImplemented()
            }
        }
    }

    /** Tells Dart the user tapped Cancel on the notification. */
    fun sendCancel() {
        main.post { channel?.invokeMethod("cancel", null) }
    }

    private fun progressFrom(args: Any?): TransferService.Progress {
        val map = args as? Map<*, *> ?: return TransferService.Progress()
        return TransferService.Progress(
            jobId = map["jobId"] as? String ?: "",
            title = map["title"] as? String ?: "Transferring frames",
            text = map["text"] as? String ?: "",
            done = (map["done"] as? Number)?.toInt() ?: 0,
            total = (map["total"] as? Number)?.toInt() ?: 0,
            upload = map["upload"] as? Boolean ?: true,
        )
    }

    /**
     * Android 13+: asks for POST_NOTIFICATIONS if not granted yet. Returns
     * whether it is granted now; a transfer runs either way (without the
     * permission the service still runs, only its notification is hidden).
     */
    private fun requestNotificationPermission(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val granted = ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        if (granted) return true
        activity?.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
        return false
    }

    /** Whether the active network is not metered (Wi-Fi and the like). */
    private fun isUnmetered(ctx: Context): Boolean {
        val cm = ctx.getSystemService(ConnectivityManager::class.java) ?: return false
        return try {
            val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) ||
                !cm.isActiveNetworkMetered
        } catch (e: Exception) {
            false
        }
    }
}
