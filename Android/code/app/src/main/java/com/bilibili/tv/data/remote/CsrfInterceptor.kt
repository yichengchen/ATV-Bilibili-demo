package com.bilibili.tv.data.remote

import okhttp3.FormBody
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject

class CsrfInterceptor @Inject constructor(
    private val cookieJar: CookieJarImpl
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        if (original.method == "POST") {
            val csrf = cookieJar.csrf()
            if (csrf.isNotEmpty()) {
                val body = original.body
                if (body is FormBody) {
                    val newBody = FormBody.Builder().apply {
                        for (i in 0 until body.size) {
                            add(body.name(i), body.value(i))
                        }
                        add("csrf", csrf)
                    }.build()
                    return chain.proceed(original.newBuilder().post(newBody).build())
                }
            }
        }
        return chain.proceed(original)
    }
}
