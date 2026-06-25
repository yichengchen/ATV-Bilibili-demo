package com.bilibili.tv.data.remote

import com.bilibili.tv.data.proto.DmProto
import com.bilibili.tv.data.proto.DmViewProto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton

@Singleton
class DanmakuApi @Inject constructor(
    @Named("wbi") private val client: OkHttpClient
) {
    suspend fun getDanmakuWebView(cid: Long): DmViewProto.DmWebViewReply? = withContext(Dispatchers.IO) {
        try {
            val url = "https://api.bilibili.com/x/v2/dm/web/view?type=1&oid=$cid"
            Timber.d("[dm] getDanmakuWebView: $url")
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { resp ->
                Timber.d("[dm] getDanmakuWebView resp: code=${resp.code}, body=${resp.body?.contentLength()}")
                val bytes = resp.body?.bytes() ?: return@withContext null
                val result = DmViewProto.DmWebViewReply.parseFrom(bytes)
                Timber.d("[dm] getDanmakuWebView parsed: commandDms=${result.commandDmsCount}")
                result
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to fetch danmaku web view for cid=$cid")
            null
        }
    }

    suspend fun getDanmakuList(cid: Long, segmentIndex: Int): DmProto.DmSegMobileReply? = withContext(Dispatchers.IO) {
        try {
            val url = "https://api.bilibili.com/x/v2/dm/list/seg.so?type=1&oid=$cid&segment_index=$segmentIndex"
            Timber.d("[dm] getDanmakuList: $url")
            val request = Request.Builder().url(url).build()
            client.newCall(request).execute().use { resp ->
                Timber.d("[dm] getDanmakuList resp: code=${resp.code}, body=${resp.body?.contentLength()}")
                val bytes = resp.body?.bytes() ?: return@withContext null
                val result = DmProto.DmSegMobileReply.parseFrom(bytes)
                Timber.d("[dm] getDanmakuList parsed: elems=${result.elemsCount}")
                result
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to fetch danmaku list cid=$cid segment=$segmentIndex")
            null
        }
    }
}
