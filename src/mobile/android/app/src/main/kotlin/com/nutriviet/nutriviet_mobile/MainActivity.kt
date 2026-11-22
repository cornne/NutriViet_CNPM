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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nutriviet/image_opt")
            .setMethodCallHandler { call, result ->
                if (call.method != "compressForOcr") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val rawBytes = call.argument<ByteArray>("bytes")
                val maxSide = call.argument<Int>("maxSide") ?: 1080
                val targetMaxBytes = call.argument<Int>("targetMaxBytes") ?: 110 * 1024
                if (rawBytes == null || rawBytes.isEmpty()) {
                    result.error("INVALID_ARGS", "Empty image bytes", null)
                    return@setMethodCallHandler
                }
                imageExecutor.execute {
                    try {
                        val compressed = compressJpegForOcr(rawBytes, maxSide, targetMaxBytes)
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
     * Fast native EXIF-aware downscale + adaptive JPEG compression so camera
     * captures (~1.5-3MB) shrink to <= 110KB in ~35ms before cross-border OCR upload.
     */
    private fun compressJpegForOcr(
        rawBytes: ByteArray,
        maxSide: Int,
        targetMaxBytes: Int
    ): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, bounds)
        val rawW = bounds.outWidth
        val rawH = bounds.outHeight
        if (rawW <= 0 || rawH <= 0) return rawBytes

        var sample = 1
        while (max(rawW / sample, rawH / sample) > maxSide * 2) {
            sample *= 2
        }
        val decodeOpts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565
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

        val scale = if (max(bmp.width, bmp.height) > maxSide) {
            maxSide.toFloat() / max(bmp.width, bmp.height).toFloat()
        } else {
            1f
        }

        if (rotation != 0f || scale < 0.99f) {
            val matrix = Matrix().apply {
                if (scale < 0.99f) postScale(scale, scale)
                if (rotation != 0f) postRotate(rotation)
            }
            val transformed = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
            if (transformed !== bmp) bmp.recycle()
            bmp = transformed
        }

        try {
            val qualities = intArrayOf(72, 62, 52, 42)
            var best = rawBytes
            for (q in qualities) {
                val baos = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, q, baos)
                best = baos.toByteArray()
                if (best.size <= targetMaxBytes) {
                    return best
                }
            }
            // If still over budget (very busy background), scale down once more to 840px
            if (best.size > targetMaxBytes && max(bmp.width, bmp.height) > 840) {
                val s2 = 840f / max(bmp.width, bmp.height).toFloat()
                val smaller = Bitmap.createScaledBitmap(
                    bmp,
                    max(1, (bmp.width * s2).toInt()),
                    max(1, (bmp.height * s2).toInt()),
                    true
                )
                try {
                    val baos = ByteArrayOutputStream()
                    smaller.compress(Bitmap.CompressFormat.JPEG, 58, baos)
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
        if (params.preferredDisplayModeId != bestMode.modeId) {
            params.preferredDisplayModeId = bestMode.modeId
            window.attributes = params
        }
    }
}
