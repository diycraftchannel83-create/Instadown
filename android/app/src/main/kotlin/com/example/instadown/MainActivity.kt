package com.example.instadown

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "instadown/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveVideo" -> {
                    try {
                        val name = call.argument<String>("name") ?: "Instagram_${System.currentTimeMillis()}.mp4"
                        val encoded = call.argument<String>("bytes") ?: ""
                        val bytes = Base64.decode(encoded, Base64.DEFAULT)
                        val values = ContentValues().apply {
                            put(MediaStore.Video.Media.DISPLAY_NAME, name)
                            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/InstaDown")
                                put(MediaStore.Video.Media.IS_PENDING, 1)
                            }
                        }
                        val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                            ?: throw Exception("Gagal membuat MediaStore entry.")
                        contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                            ?: throw Exception("Gagal menulis file.")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val done = ContentValues()
                            done.put(MediaStore.Video.Media.IS_PENDING, 0)
                            contentResolver.update(uri, done, null, null)
                        }
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("MEDIA_STORE", e.message, null)
                    }
                }
                "openMedia" -> {
                    val uri = Uri.parse(call.argument<String>("uri"))
                    startActivity(Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "video/mp4")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
