package com.yarizm.yunchuang

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File

/**
 * 把「打开方式」和「分享」进来的书籍落到缓存目录，供 Flutter 侧取走导入。
 *
 * 用拉取而不是推送：intent 在 Activity.onCreate 就到了，那时 Dart 侧还没
 * 起来，推过去会丢。这里先攒着，Flutter 启动或回到前台时调
 * `consumePending` 取。
 *
 * content:// 不是真实路径，Dart 的 File 打不开，所以必须先复制出来。
 */
object SharedFileReceiver {
    private const val CACHE_DIR = "shared_imports"
    private val supportedExtensions = setOf("epub", "pdf", "txt")

    private val pending = mutableListOf<String>()

    /** 给每份复制出来的文件分配互不相同的子目录，见 [copyToCache]。 */
    private val sequence = java.util.concurrent.atomic.AtomicLong(0)

    /** 取走并清空待导入列表。取过一次就不再返回，避免重复导入同一本。 */
    @Synchronized
    fun consumePending(): List<String> {
        val copy = pending.toList()
        pending.clear()
        return copy
    }

    @Synchronized
    private fun add(path: String) {
        if (!pending.contains(path)) pending.add(path)
    }

    fun handleIntent(context: Context, intent: Intent?) {
        if (intent == null) return
        val uris = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND ->
                listOfNotNull(intent.getParcelableExtraCompat<Uri>(Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtraCompat<Uri>(Intent.EXTRA_STREAM)
            else -> emptyList()
        }
        for (uri in uris) {
            val path = copyToCache(context, uri) ?: continue
            add(path)
        }
    }

    /**
     * 复制到缓存目录并返回本地路径，失败返回 null。
     *
     * 单个条目失败不能中断其余的：多选分享时有一个文件读不出来，其他几本
     * 仍应导入成功。
     *
     * 每份文件放进各自的子目录，而不是平铺在同一层：显示名来自外部应用，
     * 多选分享里出现两本同名的书完全正常（不同文件夹下的 book.epub）。
     * 平铺时第二份会覆盖第一份，`add` 又按路径去重，结果分享两本只导入
     * 一本且毫无提示。子目录保证不撞，同时原样保留显示名。
     */
    private fun copyToCache(context: Context, uri: Uri): String? {
        return try {
            val name = sanitize(displayName(context.contentResolver, uri) ?: return null)
            if (name.substringAfterLast('.', "").lowercase() !in supportedExtensions) {
                return null
            }
            val slot = "${System.currentTimeMillis()}_${sequence.incrementAndGet()}"
            val dir = File(File(context.cacheDir, CACHE_DIR), slot).apply { mkdirs() }
            val target = File(dir, name)
            context.contentResolver.openInputStream(uri).use { input ->
                if (input == null) return null
                target.outputStream().use { output -> input.copyTo(output) }
            }
            target.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun displayName(resolver: ContentResolver, uri: Uri): String? {
        if (uri.scheme == ContentResolver.SCHEME_FILE) return uri.lastPathSegment
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) {
                    return cursor.getString(index)
                }
            }
        return uri.lastPathSegment
    }

    /** 文件名来自外部应用，可能带路径分隔符——只取最后一段，防止写出缓存目录。 */
    private fun sanitize(raw: String): String {
        val base = raw.substringAfterLast('/').substringAfterLast('\\')
        return base.ifBlank { "shared" }
    }
}

@Suppress("DEPRECATION")
private inline fun <reified T : android.os.Parcelable> Intent.getParcelableExtraCompat(
    key: String,
): T? {
    return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(key, T::class.java)
    } else {
        getParcelableExtra(key)
    }
}

@Suppress("DEPRECATION")
private inline fun <reified T : android.os.Parcelable> Intent.getParcelableArrayListExtraCompat(
    key: String,
): List<T> {
    val list = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        getParcelableArrayListExtra(key, T::class.java)
    } else {
        getParcelableArrayListExtra<T>(key)
    }
    return list ?: emptyList()
}
