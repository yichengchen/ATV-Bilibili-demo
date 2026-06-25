package com.bilibili.tv.data.remote

import okhttp3.HttpUrl
import okhttp3.Interceptor
import okhttp3.Response
import java.security.MessageDigest
import java.util.Locale

class AppSignInterceptor : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val url = original.url

        val params = mutableMapOf<String, String>()
        for (name in url.queryParameterNames) {
            params[name] = url.queryParameter(name) ?: ""
        }

        params["appkey"] = Constants.APP_KEY
        params["ts"] = (System.currentTimeMillis() / 1000).toString()
        params["local_id"] = "0"
        params["mobi_app"] = "iphone"
        params["device"] = "pad"
        params["device_name"] = "iPad"

        params["sign"] = buildSign(params)

        val builder = HttpUrl.Builder()
            .scheme(url.scheme)
            .host(url.host)
            .encodedPath(url.encodedPath)
        params.toSortedMap().forEach { (k, v) -> builder.addQueryParameter(k, v) }

        return chain.proceed(original.newBuilder().url(builder.build()).build())
    }

    private fun buildSign(params: Map<String, String>): String {
        val raw = params.toSortedMap().entries.joinToString("&") { "${it.key}=${it.value}" } + Constants.APP_SEC
        return md5(raw)
    }

    private fun md5(input: String): String {
        val bytes = MessageDigest.getInstance("MD5").digest(input.toByteArray())
        return bytes.joinToString("") { String.format(Locale.US, "%02x", it) }
    }
}
