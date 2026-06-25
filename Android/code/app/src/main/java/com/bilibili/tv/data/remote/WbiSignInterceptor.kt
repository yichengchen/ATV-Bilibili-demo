package com.bilibili.tv.data.remote

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import timber.log.Timber
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.TimeUnit

class WbiSignInterceptor(
    private val cookieJar: CookieJarImpl
) : Interceptor {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    @Volatile private var imgKey: String? = null
    @Volatile private var subKey: String? = null
    @Volatile private var lastKeyUpdate: Long = 0
    @Volatile private var webId: String? = null

    private val plainClient = OkHttpClient.Builder()
        .cookieJar(cookieJar)
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .addInterceptor(GlobalHeadersInterceptor())
        .build()

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        if (original.method != "GET") return chain.proceed(original)

        val url = original.url
        val params = mutableMapOf<String, String>()
        for (name in url.queryParameterNames) {
            params[name] = url.queryParameter(name) ?: ""
        }

        val signed = runBlocking { encWbi(params) } ?: return chain.proceed(original)

        val builder = HttpUrl.Builder()
            .scheme(url.scheme).host(url.host).encodedPath(url.encodedPath)
        signed.forEach { (k, v) -> builder.addQueryParameter(k, v) }

        return chain.proceed(original.newBuilder().url(builder.build()).build())
    }

    private suspend fun encWbi(params: Map<String, String>): Map<String, String>? {
        return try {
            ensureWbiKeys()
            val img = imgKey
            val sub = subKey
            if (img.isNullOrEmpty() || sub.isNullOrEmpty()) return null

            val mixinKey = getMixinKey(img + sub)
            val wts = (System.currentTimeMillis() / 1000).toString()

            val result = mutableMapOf<String, String>()
            result.putAll(params)
            result["wts"] = wts
            webId?.let { result["w_webid"] = it }

            val query = result.toSortedMap().entries.joinToString("&") { (k, v) ->
                "$k=${v.filter { c -> c !in "!'()*" }}"
            }

            result["w_rid"] = md5(query + mixinKey)

            val wbiParamKeys = setOf("w_webid", "w_rid", "wts")
            val ordered = mutableListOf<String>()
            result.toSortedMap().keys.filter { it !in wbiParamKeys }.forEach { k ->
                result[k]?.let { ordered.add("$k=$it") }
            }
            listOf("w_webid", "w_rid", "wts").forEach { k ->
                result[k]?.let { ordered.add("$k=$it") }
            }
            ordered.associate { it.split("=", limit = 2).let { p -> p[0] to p.getOrElse(1) { "" } } }
        } catch (e: Exception) {
            Timber.e(e, "WBI sign failed")
            null
        }
    }

    private fun ensureWbiKeys() {
        val now = System.currentTimeMillis()
        if (!imgKey.isNullOrEmpty() && !subKey.isNullOrEmpty() && now - lastKeyUpdate < 2 * 60 * 60 * 1000) return
        fetchWbiKeys()
    }

    private fun fetchWbiKeys() {
        try {
            val request = Request.Builder()
                .url("https://api.bilibili.com/x/web-interface/nav")
                .header("User-Agent", Constants.USER_AGENT)
                .header("Referer", Constants.REFERER)
                .build()

            plainClient.newCall(request).execute().use { resp ->
                val body = resp.body?.string() ?: return
                val parsed = json.decodeFromString<NavApiResponse>(body)
                val wbi = parsed.data?.wbi_img ?: return
                imgKey = wbi.img_url.substringAfterLast("/").substringBefore(".")
                subKey = wbi.sub_url.substringAfterLast("/").substringBefore(".")
                lastKeyUpdate = System.currentTimeMillis()
                Timber.d("WBI keys fetched: img=$imgKey sub=$subKey")
                if (!imgKey.isNullOrEmpty()) fetchWebId()
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to fetch WBI keys")
        }
    }

    private fun fetchWebId() {
        try {
            val visitId = buildString { repeat(16) { append("0123456789abcdef".random()) } }
            val request = Request.Builder()
                .url("https://live.bilibili.com/p/eden/area-tags?parentAreaId=2&areaId=0&visit_id=$visitId")
                .header("User-Agent", Constants.USER_AGENT)
                .header("Referer", Constants.LIVE_REFERER)
                .build()

            plainClient.newCall(request).execute().use { resp ->
                val html = resp.body?.string() ?: return
                Regex("""window\._render_data_\s*=\s*\{"access_id":"([^"]+)"""")
                    .find(html)?.groupValues?.get(1)?.let { webId = it }
            }
        } catch (e: Exception) {
            Timber.e(e, "Failed to fetch webId")
        }
    }

    private fun getMixinKey(orig: String): String {
        val t = intArrayOf(
            46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,
            33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,
            61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,
            36,20,34,44,52
        )
        return String(t.take(32).map { orig[it] }.toCharArray())
    }

    private fun md5(input: String): String {
        val bytes = MessageDigest.getInstance("MD5").digest(input.toByteArray())
        return bytes.joinToString("") { String.format(Locale.US, "%02x", it) }
    }

    @Serializable
    private data class NavApiResponse(val code: Int = -1, val data: NavApiData? = null)

    @Serializable
    private data class NavApiData(@SerialName("wbi_img") val wbi_img: NavWbiImg? = null)

    @Serializable
    private data class NavWbiImg(
        @SerialName("img_url") val img_url: String = "",
        @SerialName("sub_url") val sub_url: String = ""
    )
}
