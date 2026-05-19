package com.budgetbuddy.app

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "budgetbuddy/storage"
	private val TAG = "MainActivity"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				Log.d(TAG, "MethodChannel $CHANNEL handler set")
				// Handler registered; will receive calls from Dart side
				
				when (call.method) {
					"saveToDownloads" -> {
						val sourcePath = call.argument<String>("sourcePath")
						val displayName = call.argument<String>("fileName")
						val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

						if (sourcePath == null || displayName == null) {
							result.error("INVALID_ARGS", "Missing sourcePath or fileName", null)
							return@setMethodCallHandler
						}

						try {
							val resolver = applicationContext.contentResolver
							val contentValues = ContentValues().apply {
								put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
								put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
								if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
									put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/")
								}
							}

							val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
							val uri = resolver.insert(collection, contentValues)
							if (uri == null) {
								Log.e(TAG, "MediaStore insert returned null")
								result.error("INSERT_FAILED", "Could not create media store entry", null)
								return@setMethodCallHandler
							}

							resolver.openOutputStream(uri).use { outStream ->
								FileInputStream(File(sourcePath)).use { inStream ->
									val buffer = ByteArray(4096)
									var read = inStream.read(buffer)
									while (read != -1) {
										outStream?.write(buffer, 0, read)
										read = inStream.read(buffer)
									}
									outStream?.flush()
								}
							}

							Log.d(TAG, "Saved file to MediaStore: $uri")
							result.success(uri.toString())
						} catch (e: Exception) {
							result.error("SAVE_FAILED", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}
}