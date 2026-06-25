package com.bilibili.tv.ui.component

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import coil.request.ImageRequest

object BiliImageSize {
    const val CARD_COVER_WIDTH = 360
    const val CARD_COVER_HEIGHT = 202
    const val DETAIL_BACKGROUND_WIDTH = 960
    const val DETAIL_BACKGROUND_HEIGHT = 540
    const val DETAIL_COVER_WIDTH = 640
    const val DETAIL_COVER_HEIGHT = 360
    const val RELATED_COVER_WIDTH = 320
    const val RELATED_COVER_HEIGHT = 180
    const val EPISODE_COVER_WIDTH = 240
    const val EPISODE_COVER_HEIGHT = 135
    const val AVATAR_SMALL = 80
    const val AVATAR_MEDIUM = 120
    const val COMMENT_IMAGE_WIDTH = 960
    const val COMMENT_IMAGE_HEIGHT = 960
}

@Composable
fun rememberBiliImageRequest(
    url: String?,
    width: Int,
    height: Int,
    format: String = "jpg"
): ImageRequest? {
    val context = LocalContext.current
    return remember(context, url, width, height, format) {
        val sizedUrl = url.biliSizedImageUrl(width = width, height = height, format = format)
            ?: return@remember null
        ImageRequest.Builder(context)
            .data(sizedUrl)
            .size(width, height)
            .build()
    }
}

fun String?.biliSizedImageUrl(
    width: Int,
    height: Int,
    format: String = "jpg"
): String? {
    val raw = this?.takeIf { it.isNotBlank() } ?: return null
    val normalized = if (raw.startsWith("//")) "https:$raw" else raw
    val queryStart = normalized.indexOf('?')
    val base = (if (queryStart >= 0) normalized.substring(0, queryStart) else normalized)
        .replace(Regex("@\\d+w_\\d+h\\.[A-Za-z0-9]+$"), "")
    val query = if (queryStart >= 0) normalized.substring(queryStart) else ""
    return "$base@${width}w_${height}h.$format$query"
}
