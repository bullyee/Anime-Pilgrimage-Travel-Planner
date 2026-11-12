package com.example.trip_planner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Keeps the app's process at foreground priority while Dart uploads or
 * downloads frames (`frame_transfer_queue.dart`), and shows the ongoing
 * notification with the progress and a Cancel action.
 *
 * It does no work of its own: the transfers run in the Dart isolate of the
 * cached FlutterEngine (see [MainActivity.provideFlutterEngine]), which
 * outlives the Activity. `stopWithTask=false` in the manifest keeps it (and
 * so the process) running when the task is swiped away from Recents.
 *
 * [TransferBridge] starts it, updates the notification and stops it; the
 * notification's Cancel comes back here as [ACTION_CANCEL] and goes to Dart.
 */
class TransferService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                TransferBridge.sendCancel()
                // Show that it was heard; Dart stops the service once the
                // frame in flight is done.
                if (!running) {
                    // A stale notification: nothing to cancel here.
                    stopSelf()
                    return START_NOT_STICKY
                }
                current = current.copy(text = "Cancelling…", cancelling = true)
                notifyProgress(this)
                return START_NOT_STICKY
            }
            else -> {
                if (!goForeground()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                running = true
                // Dart was done before Android got here (a very short job):
                // stop now that startForeground has been called.
                if (pendingStop) {
                    pendingStop = false
                    stopSelfNow()
                }
            }
        }
        // Not sticky: if Android kills the process anyway, the Dart work is
        // gone with it, and the app offers to resume on its next start.
        return START_NOT_STICKY
    }

    private fun goForeground(): Boolean = try {
        ensureChannel(this)
        val notification = buildNotification(this, current)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        true
    } catch (e: Exception) {
        // E.g. ForegroundServiceStartNotAllowedException: the transfer still
        // runs, only without the raised priority.
        Log.w(TAG, "Could not go foreground", e)
        false
    }

    /**
     * Android 15+ caps dataSync services at 6 hours a day. The transfer goes
     * on in Dart without the raised priority.
     */
    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "dataSync time limit reached; stopping the foreground service")
        stopSelfNow()
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun stopSelfNow() {
        running = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    /** What the ongoing notification shows. */
    data class Progress(
        val jobId: String = "",
        val title: String = "Transferring frames",
        val text: String = "",
        val done: Int = 0,
        val total: Int = 0,
        val upload: Boolean = true,
        val cancelling: Boolean = false,
    )

    companion object {
        private const val TAG = "TransferService"
        const val CHANNEL_ID = "frame_transfers"
        private const val NOTIFICATION_ID = 4101
        private const val DONE_NOTIFICATION_ID = 4102
        const val ACTION_START = "com.example.trip_planner.transfers.START"
        const val ACTION_CANCEL = "com.example.trip_planner.transfers.CANCEL"

        @Volatile
        var running = false
            private set

        @Volatile
        private var current = Progress()

        // stop() came before onStartCommand; stopping then would break the
        // startForegroundService contract, so the service stops itself.
        @Volatile
        private var pendingStop = false

        /** Starts the service (or refreshes it) showing [progress]. */
        fun start(context: Context, progress: Progress): Boolean {
            current = progress
            pendingStop = false
            // A new transfer replaces the last one's outcome.
            clearDone(context)
            return try {
                val intent = Intent(context, TransferService::class.java).setAction(ACTION_START)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                // Started from the background (Android 12+), or similar.
                Log.w(TAG, "Could not start the transfer service", e)
                false
            }
        }

        /** Updates the ongoing notification, if the service is up. */
        fun update(context: Context, progress: Progress) {
            // After Cancel, keep saying so until that job is over.
            val wasCancelling = current.cancelling && current.jobId == progress.jobId
            current = if (wasCancelling) progress.copy(text = current.text, cancelling = true) else progress
            if (running) notifyProgress(context)
        }

        /**
         * Stops the service. With a [title], leaves a dismissible notification
         * behind: what happened, or that the app needs the user to continue.
         */
        fun stop(context: Context, title: String?, text: String?) {
            current = Progress()
            if (running) {
                context.stopService(Intent(context, TransferService::class.java))
            } else {
                pendingStop = true
            }
            running = false
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (title != null) {
                ensureChannel(context)
                val builder = newBuilder(context)
                    .setSmallIcon(android.R.drawable.stat_sys_upload_done)
                    .setContentTitle(title)
                    .setContentText(text ?: "")
                    .setStyle(Notification.BigTextStyle().bigText(text ?: ""))
                    .setContentIntent(openAppIntent(context))
                    .setAutoCancel(true)
                manager.notify(DONE_NOTIFICATION_ID, builder.build())
            }
        }

        /** Clears the notification left by [stop], e.g. once the app is open again. */
        fun clearDone(context: Context) {
            context.getSystemService(NotificationManager::class.java)?.cancel(DONE_NOTIFICATION_ID)
        }

        private fun notifyProgress(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            try {
                manager.notify(NOTIFICATION_ID, buildNotification(context, current))
            } catch (e: Exception) {
                Log.w(TAG, "Could not update the notification", e)
            }
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(CHANNEL_ID, "Frame uploads and downloads", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Progress of frames going to or coming from Google Drive"
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }

        @Suppress("DEPRECATION")
        private fun newBuilder(context: Context): Notification.Builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                Notification.Builder(context)
            }

        private fun openAppIntent(context: Context): PendingIntent? {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
            launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            return PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun buildNotification(context: Context, p: Progress): Notification {
            val cancelIntent = PendingIntent.getService(
                context,
                1,
                Intent(context, TransferService::class.java).setAction(ACTION_CANCEL),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = newBuilder(context)
                .setSmallIcon(if (p.upload) android.R.drawable.stat_sys_upload else android.R.drawable.stat_sys_download)
                .setContentTitle(p.title)
                .setContentText(p.text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(openAppIntent(context))
                .setProgress(p.total, p.done.coerceAtMost(p.total), p.total <= 0)
            if (!p.cancelling) {
                builder.addAction(
                    Notification.Action.Builder(
                        Icon.createWithResource(context, android.R.drawable.ic_menu_close_clear_cancel),
                        "Cancel",
                        cancelIntent,
                    ).build(),
                )
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            }
            return builder.build()
        }
    }
}
