package com.example.trip_planner

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.media.ExifInterface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Display
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * A small floating window (SYSTEM_ALERT_WINDOW) that shows the anime
 * reference on top of the phone's camera app.
 *
 * Only the window itself takes touches, so the camera's shutter, focus and
 * zoom keep working everywhere else — there's no lock/adjust mode to switch.
 * On the window:
 *  - drag to move it
 *  - pinch to resize it (aspect ratio locked)
 *  - tap to show a bar with opacity − / + and ✕ (close); it fades out
 *    quickly soon after the last touch, and a tap while it shows (or fades)
 *    hides it at once
 *  - double-tap to shrink it to a small round dot of the frame, out of the
 *    way; drag the dot anywhere, and tap it to open the window again as it
 *    was (holding it would close it too easily mid-drag, so it doesn't)
 *
 * Given several frames of one spot, the bar also has ‹ › and a "3/7" count
 * to switch frames in place: the window keeps its place, width and opacity,
 * and [onFrameChanged] reports each switch. There's no swipe to switch,
 * since one finger on the image already drags the window.
 *
 * [MainActivity] hides the window while the user is in another app and shows
 * it again when they come back to the camera ([setShown]).
 *
 * Revives the April prototype (`OverlayService`) without its foreground
 * service: the Activity creates and removes the window, as in
 * anime_camera_studio, so no notification and no foreground-service
 * permissions are needed.
 */
class ReferenceOverlay(
    activity: Context,
    private val onFrameChanged: (Int) -> Unit = {},
) {
    /** Where the window was and how it looked, to put it back the same way. */
    data class Placement(val x: Int, val y: Int, val width: Int, val alpha: Float)

    // On Android 11+ the window lives in its own WindowContext. Its
    // configuration follows the display as the phone rotates, while the
    // Activity's stays in the orientation the app was last shown in — with the
    // Activity's context the window stayed boxed into a portrait-sized strip
    // of a landscape screen, both when moving and when resizing.
    private val context: Context =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val display = (activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager)
                .getDisplay(Display.DEFAULT_DISPLAY)
            activity.createDisplayContext(display)
                .createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        } else {
            activity
        }
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val displays = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val metrics get() = context.resources.displayMetrics
    private val handler = Handler(Looper.getMainLooper())
    private val hideBarRunnable = Runnable { fadeOutBar() }
    private val keepOnScreenRunnable = Runnable { keepOnScreen() }

    // Rotating the phone swaps the screen's width and height under the
    // window; pull it back inside the new bounds once the window has been
    // laid out for the new rotation.
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            if (displayId != Display.DEFAULT_DISPLAY) return
            handler.removeCallbacks(keepOnScreenRunnable)
            handler.postDelayed(keepOnScreenRunnable, ROTATION_SETTLE_MS)
        }
    }

    private var root: LinearLayout? = null
    private var frame: FrameLayout? = null
    private var image: ImageView? = null
    private var bar: LinearLayout? = null
    private var counter: TextView? = null
    private var dot: FrameLayout? = null
    private var dotImage: ImageView? = null
    private var params: WindowManager.LayoutParams? = null

    /** Shrunk to the dot (a double-tap); a tap on the dot opens it again. */
    private var collapsed = false

    // The frames to switch between, and the one showing.
    private var paths: List<String> = emptyList()
    private var current = 0

    /** The window's placement when it was last closed (by [hide] or ✕). */
    var lastPlacement: Placement? = null
        private set

    // Image width / height, and the image's on-screen width in px (the
    // height follows the aspect ratio).
    private var aspect = 16f / 9f
    private var imageWidth = 0

    /**
     * Shows [frames] starting on [index] (one frame for a single reference),
     * at [opacity]. With [placement], the window goes back there, at that
     * width and opacity; otherwise it starts small near the top.
     */
    fun show(
        frames: List<String>,
        index: Int,
        opacity: Float,
        placement: Placement? = null,
    ): Boolean {
        if (frames.isEmpty()) return false
        paths = frames
        current = index.coerceIn(0, frames.lastIndex)
        val bitmap = decode(paths[current]) ?: return false
        aspect = bitmap.width.toFloat() / bitmap.height
        val screen = screenBounds()
        val landscape = screen.width() > screen.height()
        // Start at ~45% of the screen's short side, in a top corner away
        // from the shutter: camera apps put it at the bottom in portrait and
        // on the right in landscape.
        imageWidth = (placement?.width ?: (min(screen.width(), screen.height()) * 0.45f).roundToInt())
            .coerceIn(minWidth(), maxWidth(screen))

        val image = ImageView(context).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.FIT_XY
            alpha = (placement?.alpha ?: opacity).coerceIn(MIN_ALPHA, 1f)
        }
        val imageFrame = FrameLayout(context).apply {
            background = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                setStroke(dp(2f), Color.WHITE)
                cornerRadius = dp(4f).toFloat()
            }
            val pad = dp(2f)
            setPadding(pad, pad, pad, pad)
            addView(
                image,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
            setOnTouchListener(TouchHandler())
        }
        val controls = buildBar(image)
        val dotImage = ImageView(context).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.CENTER_CROP
            clipToOutline = true
            outlineProvider = ViewOutlineProvider.BACKGROUND
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL }
        }
        val dotView = FrameLayout(context).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xCC202124.toInt())
                setStroke(dp(2f), Color.WHITE)
            }
            val pad = dp(3f)
            setPadding(pad, pad, pad, pad)
            addView(
                dotImage,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
            contentDescription = "Reference, shrunk. Tap to open it again."
            visibility = View.GONE
            setOnTouchListener(TouchHandler(onDot = true))
        }
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            addView(dotView, LinearLayout.LayoutParams(dp(DOT_DP), dp(DOT_DP)))
            addView(imageFrame, LinearLayout.LayoutParams(imageWidth, imageHeight()))
            addView(
                controls,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ),
            )
        }
        val layout = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            if (placement != null) {
                x = placement.x
                y = placement.y
                clamp(this, screen)
            } else {
                x = screen.right - imageWidth - dp(12f)
                y = screen.top + if (landscape) dp(24f) else dp(96f)
            }
        }

        return try {
            wm.addView(column, layout)
            root = column
            frame = imageFrame
            this.image = image
            bar = controls
            dot = dotView
            this.dotImage = dotImage
            collapsed = false
            params = layout
            displays.registerDisplayListener(displayListener, handler)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** False once closed — by the caller, or by the user (✕). */
    val isShowing: Boolean get() = root != null

    /**
     * Shows or hides the window without removing it, so it comes back where
     * it was and at the same size — for when the user leaves the camera for
     * another app and then returns.
     */
    fun setShown(shown: Boolean) {
        val view = root ?: return
        val visibility = if (shown) View.VISIBLE else View.GONE
        if (view.visibility == visibility) return
        view.visibility = visibility
        if (!shown) hideBar()
    }

    fun hide() {
        hideBar()
        handler.removeCallbacks(keepOnScreenRunnable)
        runCatching { displays.unregisterDisplayListener(displayListener) }
        val layout = params
        val shown = image
        if (layout != null && shown != null) {
            lastPlacement = Placement(layout.x, layout.y, imageWidth, shown.alpha)
        }
        root?.let { runCatching { wm.removeView(it) } }
        root = null
        frame = null
        image = null
        bar = null
        counter = null
        dot = null
        dotImage = null
        collapsed = false
        params = null
    }

    /**
     * Shrinks the window to the dot, at the window's top-left corner, or
     * opens it again from the dot at the dot's place, keeping its width and
     * opacity.
     */
    private fun setCollapsed(value: Boolean) {
        val layout = params ?: return
        val view = root ?: return
        if (collapsed == value) return
        collapsed = value
        hideBar()
        frame?.visibility = if (value) View.GONE else View.VISIBLE
        dot?.visibility = if (value) View.VISIBLE else View.GONE
        clamp(layout, screenBounds())
        runCatching { wm.updateViewLayout(view, layout) }
    }

    /**
     * Shows the frame [step] away from the current one, wrapping around at
     * either end, and reports it. A frame that won't decode is skipped.
     */
    private fun switchFrame(step: Int) {
        val count = paths.size
        if (count < 2 || root == null) return
        var next = current
        repeat(count - 1) {
            next = Math.floorMod(next + step, count)
            val bitmap = decode(paths[next]) ?: return@repeat
            current = next
            showBitmap(bitmap)
            onFrameChanged(current)
            return
        }
    }

    /** Puts [bitmap] in the window at the same place and width; its height follows the frame's shape. */
    private fun showBitmap(bitmap: Bitmap) {
        val layout = params ?: return
        val view = root ?: return
        image?.setImageBitmap(bitmap)
        dotImage?.setImageBitmap(bitmap)
        counter?.text = countText()
        aspect = bitmap.width.toFloat() / bitmap.height
        val screen = screenBounds()
        setImageWidth(imageWidth.coerceIn(minWidth(), maxWidth(screen)))
        clamp(layout, screen)
        runCatching { wm.updateViewLayout(view, layout) }
    }

    private fun countText(): String = "${current + 1}/${paths.size}"

    /**
     * Opacity − / + and ✕, shown under the image after a tap, with ‹ › and
     * the frame's number around them when there are several frames. A
     * double-tap shrinks the window to a dot instead of closing it, so ✕ is
     * the way to close it from here.
     */
    private fun buildBar(image: ImageView): LinearLayout {
        fun button(label: String, description: String, onClick: () -> Unit) =
            TextView(context).apply {
                text = label
                contentDescription = description
                setTextColor(Color.WHITE)
                textSize = 18f
                gravity = Gravity.CENTER
                setOnClickListener {
                    // Back to full strength if it had started to fade.
                    showBar()
                    onClick()
                }
            }

        val frames = paths.size > 1
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(0xCC202124.toInt())
            visibility = View.GONE
            val slot = { LinearLayout.LayoutParams(0, dp(40f), 1f) }
            if (frames) {
                addView(button("‹", "Previous frame") { switchFrame(-1) }, slot())
            }
            addView(
                button("−", "Fainter reference") {
                    image.alpha = (image.alpha - 0.1f).coerceIn(MIN_ALPHA, 1f)
                },
                slot(),
            )
            if (frames) {
                val count = TextView(context).apply {
                    text = countText()
                    setTextColor(Color.WHITE)
                    textSize = 12f
                    gravity = Gravity.CENTER
                }
                counter = count
                addView(count, slot())
            }
            addView(
                button("+", "Stronger reference") {
                    image.alpha = (image.alpha + 0.1f).coerceIn(MIN_ALPHA, 1f)
                },
                slot(),
            )
            if (frames) {
                addView(button("›", "Next frame") { switchFrame(1) }, slot())
            }
            addView(button("✕", "Close the reference") { hide() }, slot())
        }
    }

    /** Shows the bar at full strength, to fade out once left alone. */
    private fun showBar() {
        val controls = bar ?: return
        controls.animate().cancel()
        controls.alpha = 1f
        controls.visibility = View.VISIBLE
        handler.removeCallbacks(hideBarRunnable)
        handler.postDelayed(hideBarRunnable, BAR_TIMEOUT_MS)
    }

    /** Hides the bar at once, mid-fade too. */
    private fun hideBar() {
        handler.removeCallbacks(hideBarRunnable)
        val controls = bar ?: return
        controls.animate().cancel()
        controls.visibility = View.GONE
        controls.alpha = 1f
    }

    private fun fadeOutBar() {
        val controls = bar ?: return
        if (controls.visibility != View.VISIBLE) return
        // The end action only runs if the fade isn't cancelled by a touch.
        controls.animate().alpha(0f).setDuration(BAR_FADE_MS).withEndAction { hideBar() }.start()
    }

    private fun moveBy(dx: Float, dy: Float) {
        val layout = params ?: return
        val view = root ?: return
        layout.x = (layout.x + dx).roundToInt()
        layout.y = (layout.y + dy).roundToInt()
        clamp(layout, screenBounds())
        runCatching { wm.updateViewLayout(view, layout) }
    }

    /** Resize around the window's centre, keeping the aspect ratio. */
    private fun resizeBy(factor: Float) {
        val layout = params ?: return
        val view = root ?: return
        val screen = screenBounds()
        val oldWidth = imageWidth
        val oldHeight = imageHeight()
        setImageWidth((imageWidth * factor).roundToInt().coerceIn(minWidth(), maxWidth(screen)))
        layout.x -= (imageWidth - oldWidth) / 2
        layout.y -= (imageHeight() - oldHeight) / 2
        clamp(layout, screen)
        runCatching { wm.updateViewLayout(view, layout) }
    }

    /** After a rotation: shrink the window if it no longer fits, and pull it back on screen. */
    private fun keepOnScreen() {
        val layout = params ?: return
        val view = root ?: return
        val screen = screenBounds()
        setImageWidth(imageWidth.coerceAtMost(maxWidth(screen)))
        clamp(layout, screen)
        runCatching { wm.updateViewLayout(view, layout) }
    }

    // Sets the height too, which follows the frame's shape even when the
    // width stays.
    private fun setImageWidth(width: Int) {
        val imageFrame = frame ?: return
        imageWidth = width
        imageFrame.layoutParams = (imageFrame.layoutParams as LinearLayout.LayoutParams).apply {
            this.width = imageWidth
            height = imageHeight()
        }
    }

    /** Keep the image (or the dot) fully inside [screen]. */
    private fun clamp(layout: WindowManager.LayoutParams, screen: Rect) {
        val width = if (collapsed) dp(DOT_DP) else imageWidth
        val height = if (collapsed) dp(DOT_DP) else imageHeight()
        layout.x = layout.x.coerceIn(screen.left, max(screen.left, screen.right - width))
        layout.y = layout.y.coerceIn(screen.top, max(screen.top, screen.bottom - height))
    }

    /**
     * Where the window may go, in screen px: the whole display in its current
     * rotation, minus the status / navigation bars and any cutout. Re-read on
     * every move, resize and rotation.
     */
    private fun screenBounds(): Rect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val current = wm.currentWindowMetrics
            val bounds = Rect(current.bounds)
            val insets = current.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            bounds.left += insets.left
            bounds.top += insets.top
            bounds.right -= insets.right
            bounds.bottom -= insets.bottom
            return bounds
        }
        val bounds = Rect()
        root?.getWindowVisibleDisplayFrame(bounds)
        if (bounds.isEmpty) bounds.set(0, 0, metrics.widthPixels, metrics.heightPixels)
        return bounds
    }

    /**
     * One finger drags, two fingers resize. Positions come from raw screen
     * coordinates, so moving the window doesn't feed back into the math, and
     * a drag only resumes after every finger has lifted — lifting one finger
     * of a pinch can't make the window jump.
     */
    private inner class TouchHandler(private val onDot: Boolean = false) : View.OnTouchListener {
        private val taps = GestureDetector(
            context,
            if (onDot) {
                // The dot: a tap opens the window again. No double-tap
                // here, so a tap acts at once.
                object : GestureDetector.SimpleOnGestureListener() {
                    override fun onSingleTapUp(e: MotionEvent): Boolean {
                        setCollapsed(false)
                        return true
                    }
                }
            } else {
                object : GestureDetector.SimpleOnGestureListener() {
                    override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                        if (bar?.visibility == View.VISIBLE) hideBar() else showBar()
                        return true
                    }

                    override fun onDoubleTap(e: MotionEvent): Boolean {
                        setCollapsed(true)
                        return true
                    }
                }
            },
        ).apply { setIsLongpressEnabled(false) }
        private val pinch = ScaleGestureDetector(
            context,
            object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                override fun onScale(detector: ScaleGestureDetector): Boolean {
                    resizeBy(detector.scaleFactor)
                    return true
                }
            },
        )
        private var lastX = 0f
        private var lastY = 0f
        private var dragging = false

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouch(v: View, e: MotionEvent): Boolean {
            taps.onTouchEvent(e)
            if (!onDot) pinch.onTouchEvent(e)
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    lastX = e.rawX
                    lastY = e.rawY
                    dragging = true
                }
                MotionEvent.ACTION_POINTER_DOWN -> dragging = false
                MotionEvent.ACTION_MOVE ->
                    if (dragging && e.pointerCount == 1 && (onDot || !pinch.isInProgress)) {
                        moveBy(e.rawX - lastX, e.rawY - lastY)
                        lastX = e.rawX
                        lastY = e.rawY
                    }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> dragging = false
            }
            return true
        }
    }

    /** Decode [path] at most [MAX_DECODE_SIDE] px on its long side, upright. */
    private fun decode(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_DECODE_SIDE) {
            sample *= 2
        }
        val bitmap = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        // BitmapFactory ignores EXIF orientation; turn photos upright.
        val degrees = when (
            runCatching {
                ExifInterface(path).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> return bitmap
        }
        return Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height,
            Matrix().apply { postRotate(degrees) }, true,
        )
    }

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun imageHeight(): Int = (imageWidth / aspect).roundToInt()

    // Wide enough for the bar's buttons (six with several frames, three
    // without); the image never outgrows the screen in either direction.
    private fun minWidth(): Int = dp(if (paths.size > 1) 232f else 132f)
    private fun maxWidth(screen: Rect): Int =
        max(minWidth(), min(screen.width(), (screen.height() * aspect).roundToInt()))

    private fun dp(value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, metrics).roundToInt()

    private companion object {
        const val MIN_ALPHA = 0.15f
        const val MAX_DECODE_SIDE = 1600
        // The bar waits this long after the last touch, then fades this fast.
        const val BAR_TIMEOUT_MS = 1500L
        const val BAR_FADE_MS = 150L
        const val ROTATION_SETTLE_MS = 300L
        const val DOT_DP = 48f
    }
}
