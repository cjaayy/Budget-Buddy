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
import android.content.Intent
import android.net.Uri
import java.io.BufferedReader
import java.io.InputStreamReader

import android.app.Activity

class MainActivity : FlutterActivity() {
	private val CHANNEL = "budgetbuddy/storage"
	private val TAG = "MainActivity"
	private var pendingResult: MethodChannel.Result? = null
	private val PICK_JSON_REQUEST = 5678

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				Log.d(TAG, "MethodChannel $CHANNEL handler set")
				// Handler registered; will receive calls from Dart side
				
				when (call.method) {
					"pickJson" -> {
						if (pendingResult != null) {
							result.error("BUSY", "Picker already active", null)
							return@setMethodCallHandler
						}
						pendingResult = result
						val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
							addCategory(Intent.CATEGORY_OPENABLE)
							type = "*/*"
							putExtra(
								Intent.EXTRA_MIME_TYPES,
								arrayOf(
									"application/json",
									"text/plain",
									"text/json",
									"application/octet-stream",
									"*/*"
								)
							)
						}
						startActivityForResult(intent, PICK_JSON_REQUEST)
						return@setMethodCallHandler
					}
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

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode == PICK_JSON_REQUEST) {
			val result = pendingResult
			pendingResult = null
			if (result == null) return
			if (resultCode != Activity.RESULT_OK || data == null) {
				result.success(null)
				return
			}
			val uri: Uri? = data.data
			if (uri == null) {
				result.error("NO_URI", "No file selected", null)
				return
			}
			try {
				val resolver = applicationContext.contentResolver
				resolver.openInputStream(uri).use { inputStream ->
					if (inputStream == null) {
						result.error("READ_FAILED", "Could not open selected file", null)
						return
					}
					val text = inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
					result.success(text)
				}
			} catch (e: Exception) {
				result.error("READ_FAILED", e.message, null)
			}
		}
	}
}