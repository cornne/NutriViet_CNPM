package com.nutriviet.nutriviet_mobile

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val imageExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestHighestRefreshRate()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            requestHighestRefreshRate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nutriviet/image_opt")
            .setMethodCallHandler { call, result ->
                if (call.method != "compressForOcr") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val rawBytes = call.argument<ByteArray>("bytes")
                val maxSide = call.argument<Int>("maxSide") ?: 1280
                val targetMaxBytes = call.argument<Int>("targetMaxBytes") ?: 180 * 1024
                val cropLeft = call.argument<Double>("cropLeft")
                val cropTop = call.argument<Double>("cropTop")
                val cropWidth = call.argument<Double>("cropWidth")
                val cropHeight = call.argument<Double>("cropHeight")
                if (rawBytes == null || rawBytes.isEmpty()) {
                    result.error("INVALID_ARGS", "Empty image bytes", null)
                    return@setMethodCallHandler
                }
                imageExecutor.execute {
                    try {
                        val compressed = compressJpegForOcr(
                            rawBytes = rawBytes,
                            maxSide = maxSide,
                            targetMaxBytes = targetMaxBytes,
                            cropLeft = cropLeft,
                            cropTop = cropTop,
                            cropWidth = cropWidth,
                            cropHeight = cropHeight
                        )
                        mainHandler.post { result.success(compressed) }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error("COMPRESS_ERROR", e.message ?: "Compression failed", null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        imageExecutor.shutdownNow()
        super.onDestroy()
    }

    /**
     * Fast native EXIF-aware crop + downscale + adaptive JPEG compression off the
     * main thread (~25-45ms) so camera/gallery captures stay crisp for PaddleOCR
     * while cropping strictly to the user's selected frame.
     */
    private fun compressJpegForOcr(
        rawBytes: ByteArray,
        maxSide: Int,
        targetMaxBytes: Int,
        cropLeft: Double? = null,
        cropTop: Double? = null,
        cropWidth: Double? = null,
        cropHeight: Double? = null
    ): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, bounds)
        val rawW = bounds.outWidth
        val rawH = bounds.outHeight
        if (rawW <= 0 || rawH <= 0) return rawBytes

        val hasCrop = cropLeft != null &&
            cropTop != null &&
            cropWidth != null &&
            cropHeight != null &&
            cropWidth > 0.05 &&
            cropHeight > 0.05 &&
            (cropWidth < 0.995 || cropHeight < 0.995 || cropLeft > 0.005 || cropTop > 0.005)

        // Preserve full native sharpness inside cropped strip before downscaling
        val minCropFraction = if (hasCrop) {
            max(0.25, kotlin.math.min(cropWidth!!, cropHeight!!))
        } else {
            1.0
        }
        val decodeTargetSide = (maxSide / minCropFraction).toInt().coerceAtMost(2800)

        var sample = 1
        while (max(rawW / sample, rawH / sample) > decodeTargetSide * 2) {
            sample *= 2
        }
        val decodeOpts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        var bmp = BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, decodeOpts)
            ?: return rawBytes

        val rotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val exif = ExifInterface(ByteArrayInputStream(rawBytes))
                when (exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            } catch (_: Throwable) {
                0f
            }
        } else {
            0f
        }

        // Step 1: Rotate to upright display orientation BEFORE cropping
        if (rotation != 0f) {
            val matrix = Matrix().apply { postRotate(rotation) }
            val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
            if (rotated !== bmp) bmp.recycle()
            bmp = rotated
        }

        // Step 2: Apply exact normalized crop rectangle in upright coordinates
        if (hasCrop) {
            val l = cropLeft!!.coerceIn(0.0, 0.95)
            val t = cropTop!!.coerceIn(0.0, 0.95)
            val wFrac = cropWidth!!.coerceIn(0.05, 1.0 - l)
            val hFrac = cropHeight!!.coerceIn(0.05, 1.0 - t)

            val cx = (l * bmp.width).toInt().coerceIn(0, bmp.width - 1)
            val cy = (t * bmp.height).toInt().coerceIn(0, bmp.height - 1)
            val cw = (wFrac * bmp.width).toInt().coerceIn(1, bmp.width - cx)
            val ch = (hFrac * bmp.height).toInt().coerceIn(1, bmp.height - cy)

            if (cw < bmp.width || ch < bmp.height) {
                val cropped = Bitmap.createBitmap(bmp, cx, cy, cw, ch)
                if (cropped !== bmp) bmp.recycle()
                bmp = cropped
            }
        }

        // Step 3: Downscale cleanly if longer side exceeds maxSide
        val longest = max(bmp.width, bmp.height)
        if (longest > maxSide) {
            val scale = maxSide.toFloat() / longest.toFloat()
            val scaled = Bitmap.createScaledBitmap(
                bmp,
                max(1, (bmp.width * scale).toInt()),
                max(1, (bmp.height * scale).toInt()),
                true
            )
            if (scaled !== bmp) bmp.recycle()
            bmp = scaled
        }

        try {
            val qualities = intArrayOf(82, 74, 66, 58)
            var best = rawBytes
            for (q in qualities) {
                val baos = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, q, baos)
                best = baos.toByteArray()
                if (best.size <= targetMaxBytes) {
                    return best
                }
            }
            if (best.size > targetMaxBytes && max(bmp.width, bmp.height) > 960) {
                val s2 = 960f / max(bmp.width, bmp.height).toFloat()
                val smaller = Bitmap.createScaledBitmap(
                    bmp,
                    max(1, (bmp.width * s2).toInt()),
                    max(1, (bmp.height * s2).toInt()),
                    true
                )
                try {
                    val baos = ByteArrayOutputStream()
                    smaller.compress(Bitmap.CompressFormat.JPEG, 66, baos)
                    return baos.toByteArray()
                } finally {
                    if (smaller !== bmp) smaller.recycle()
                }
            }
            return best
        } finally {
            bmp.recycle()
        }
    }

    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return

        val activeMode = currentDisplay.mode
        // Request highest refresh rate at current resolution so 120Hz displays don't throttle down.
        val bestMode = currentDisplay.supportedModes
            .filter {
                it.physicalWidth == activeMode.physicalWidth &&
                    it.physicalHeight == activeMode.physicalHeight
            }
            .maxByOrNull { it.refreshRate }
            ?: return

        val params = window.attributes
        var changed = false
        if (params.preferredDisplayModeId != bestMode.modeId) {
            params.preferredDisplayModeId = bestMode.modeId
            changed = true
        }
        if (params.preferredRefreshRate != bestMode.refreshRate) {
            params.preferredRefreshRate = bestMode.refreshRate
            changed = true
        }
        if (changed) {
            window.attributes = params
        }
    }
}
