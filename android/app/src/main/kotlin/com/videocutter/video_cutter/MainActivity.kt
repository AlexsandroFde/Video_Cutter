package com.videocutter.video_cutter

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "video_cutter/media_store",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveAudio" -> {
                    try {
                        saveAudio(
                            path = call.argument<String>("path")!!,
                            album = call.argument<String>("album")!!,
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("save_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Publica um arquivo de áudio em `Music/<album>` via MediaStore, para
     * ele aparecer nos players e no gerenciador de arquivos.
     * O gal (usado para vídeo) não suporta a coleção de áudio.
     */
    private fun saveAudio(path: String, album: String) {
        val source = File(path)
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, source.name)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Audio.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_MUSIC + File.separator + album,
                )
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            } else {
                // Android 9 ou menor: caminho direto no armazenamento externo
                // (WRITE_EXTERNAL_STORAGE já concedida pelo fluxo do app).
                val dir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
                    album,
                )
                dir.mkdirs()
                var target = File(dir, source.name)
                var suffix = 1
                while (target.exists()) {
                    target = File(
                        dir,
                        "${source.nameWithoutExtension} (${suffix++}).${source.extension}",
                    )
                }
                put(MediaStore.Audio.Media.DATA, target.path)
            }
        }

        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore recusou o arquivo")
        resolver.openOutputStream(uri).use { output ->
            requireNotNull(output) { "não foi possível abrir o destino" }
            source.inputStream().use { it.copyTo(output) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }
}
