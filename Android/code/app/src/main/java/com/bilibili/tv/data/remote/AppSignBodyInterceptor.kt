package com.bilibili.tv.data.remote

import okhttp3.FormBody
import okhttp3.HttpUrl
import okhttp3.Interceptor
import okhttp3.Response
import java.security.MessageDigest
import java.util.Locale

class AppSignBodyInterceptor(
    private val tokenProvider: () -> String? = { null }
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        if (original.method != "POST") return chain.proceed(original)

        val params = mutableMapOf<String, String>()

        // Read query params from URL
        for (name in original.url.queryParameterNames) {
            params[name] = original.url.queryParameter(name) ?: ""
        }

        // Read existing form body params
        if (original.body is FormBody) {
            val body = original.body as FormBody
            for (i in 0 until body.size) {
                params[body.name(i)] = body.value(i)
            }
        }

        // Add access_key from token
        tokenProvider()?.let { params["access_key"] = it }

        // Add app signing params
        params["appkey"] = Constants.APP_KEY
        params["ts"] = (System.currentTimeMillis() / 1000).toString()
        params["local_id"] = "0"
        params["mobi_app"] = "iphone"
        params["device"] = "pad"
        params["device_name"] = "iPad"
        params["sign"] = buildSign(params)

        // Remove query params from URL (they go into body now)
        val cleanUrl = original.url.newBuilder().build().let { url ->
            HttpUrl.Builder()
                .scheme(url.scheme)
                .host(url.host)
                .encodedPath(url.encodedPath)
                .build()
        }

        // Build new form body with ALL params
        val newBody = FormBody.Builder().apply {
            params.forEach { (k, v) -> add(k, v) }
        }.build()

        val newRequest = original.newBuilder()
            .url(cleanUrl)
            .post(newBody)
            .build()

        return chain.proceed(newRequest)
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
