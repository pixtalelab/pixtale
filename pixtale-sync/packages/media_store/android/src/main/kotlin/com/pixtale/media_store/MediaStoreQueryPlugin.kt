package com.pixtale.media_store

import android.content.Context
import android.database.Cursor
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/// 一次查询一批 MediaStore 资产的字节数，或一次扫出带最新修改时间的相册。
class MediaStoreQueryPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "pixtale_sync/media_store")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "querySizes" -> querySizes(call, result)
            "queryAlbums" ->
                Thread {
                    try {
                        result.success(queryAlbums())
                    } catch (error: Exception) {
                        result.error("query_failed", error.message, null)
                    }
                }.start()
            else -> result.notImplemented()
        }
    }

    private fun querySizes(call: MethodCall, result: Result) {
        val ids = call.argument<List<String>>("ids").orEmpty()
        if (ids.isEmpty()) {
            result.success(emptyMap<String, Long>())
            return
        }
        val resolver = context?.contentResolver
        if (resolver == null) {
            result.error("no_context", "MediaStore query is missing app context", null)
            return
        }
        val placeholders = ids.joinToString(",") { "?" }
        val sizes = HashMap<String, Long>(ids.size)
        resolver.query(
            MediaStore.Files.getContentUri("external"),
            arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.SIZE),
            "${MediaStore.MediaColumns._ID} IN ($placeholders)",
            ids.toTypedArray(),
            null,
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val sizeIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            while (cursor.moveToNext()) {
                sizes[cursor.getLong(idIndex).toString()] = cursor.getLong(sizeIndex)
            }
        }
        result.success(sizes)
    }

    /// 一次扫出全部图片和视频相册，并记下每个相册最新的 DATE_MODIFIED。
    private fun queryAlbums(): List<Map<String, Any>> {
        val resolver = context?.contentResolver
            ?: throw IllegalStateException("MediaStore query is missing app context")
        val albums = LinkedHashMap<String, AlbumRow>()
        resolver.query(
            MediaStore.Files.getContentUri("external"),
            arrayOf(
                MediaStore.MediaColumns.BUCKET_ID,
                MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
                MediaStore.MediaColumns.DATE_MODIFIED,
            ),
            "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?)",
            arrayOf(
                MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
                MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
            ),
            null,
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_ID)
            val nameIndex =
                cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            val modifiedIndex =
                cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            while (cursor.moveToNext()) {
                val id = cursor.bucketId(idIndex)
                if (id.isEmpty()) continue
                val name = cursor.getString(nameIndex).orEmpty()
                val modified =
                    if (cursor.isNull(modifiedIndex)) 0L else cursor.getLong(modifiedIndex)
                val current = albums[id]
                if (current == null || modified > current.modified) {
                    albums[id] =
                        AlbumRow(id, name.ifEmpty { current?.name.orEmpty() }, modified)
                } else if (current.name.isEmpty() && name.isNotEmpty()) {
                    current.name = name
                }
            }
        }
        return albums.values
            .sortedWith(compareByDescending<AlbumRow> { it.modified }.thenBy { it.id })
            .map { album ->
                mapOf(
                    "id" to album.id,
                    "name" to album.name,
                    "modified" to album.modified,
                )
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    private class AlbumRow(
        val id: String,
        var name: String,
        val modified: Long,
    )
}

private fun Cursor.bucketId(index: Int): String {
    return when (getType(index)) {
        Cursor.FIELD_TYPE_INTEGER -> getLong(index).toString()
        Cursor.FIELD_TYPE_NULL -> ""
        else -> getString(index).orEmpty()
    }
}
