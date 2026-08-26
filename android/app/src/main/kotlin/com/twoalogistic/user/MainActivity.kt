package com.twoalogistic.user

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.twoalogistic.user/update"
    private val textRecognitionChannel = "com.twoalogistic.user/text_recognition"

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Prevent Android's call-key fallback from hitting restricted CLOSE_SYSTEM_DIALOGS.
        if (event.keyCode == KeyEvent.KEYCODE_CALL) {
            return true
        }

        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("NO_PATH", "APK path is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }
                    "canInstallPackages" -> {
                        result.success(canInstallPackages())
                    }
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            textRecognitionChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "recognizeText") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("NO_PATH", "Image path is required", null)
                return@setMethodCallHandler
            }

            recognizeText(path, result)
        }
    }

    private fun recognizeText(path: String, result: MethodChannel.Result) {
        val imageFile = File(path)
        if (!imageFile.exists()) {
            result.error("IMAGE_NOT_FOUND", "Selected image was not found", null)
            return
        }

        try {
            val image = InputImage.fromFilePath(this, android.net.Uri.fromFile(imageFile))
            val recognizer = TextRecognition.getClient(
                ChineseTextRecognizerOptions.Builder().build()
            )
            recognizer.process(image)
                .addOnSuccessListener { recognized ->
                    result.success(recognized.text)
                    recognizer.close()
                }
                .addOnFailureListener { error ->
                    result.error("OCR_FAILED", error.message, null)
                    recognizer.close()
                }
        } catch (error: Exception) {
            result.error("OCR_FAILED", error.message, null)
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) throw Exception("APK file not found: $path")

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }

        startActivity(intent)
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                android.net.Uri.parse("package:$packageName")
            )
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        }
    }
}
