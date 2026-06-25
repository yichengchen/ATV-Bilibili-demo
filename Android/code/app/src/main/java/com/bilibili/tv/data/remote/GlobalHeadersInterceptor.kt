package com.bilibili.tv.data.remote

import okhttp3.Interceptor
import okhttp3.Response

class GlobalHeadersInterceptor(
    private val tokenProvider: () -> String? = { null }
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val builder = original.newBuilder()
            .header("User-Agent", Constants.USER_AGENT)
            .header("Referer", Constants.REFERER)

        tokenProvider()?.let { token ->
            if (original.url.queryParameter("access_key").isNullOrEmpty()) {
                val url = original.url.newBuilder()
                    .addQueryParameter("access_key", token)
                    .build()
                builder.url(url)
            }
        }

        return chain.proceed(builder.build())
    }
}
