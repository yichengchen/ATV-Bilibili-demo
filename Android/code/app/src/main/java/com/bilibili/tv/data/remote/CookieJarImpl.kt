package com.bilibili.tv.data.remote

import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CookieJarImpl @Inject constructor() : CookieJar {
    private val store = mutableMapOf<String, MutableList<Cookie>>()

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        for (cookie in cookies) {
            val domain = cookie.domain.removePrefix(".")
            store.getOrPut(domain) { mutableListOf() }.apply {
                removeAll { it.name == cookie.name }
                add(cookie)
            }
            Timber.d("Cookie saved: ${cookie.name}=${cookie.value.take(20)}... domain=${cookie.domain}")
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val host = url.host
        val candidates = mutableListOf<Cookie>()
        store.forEach { (domain, cookies) ->
            if (host == domain || host.endsWith(".$domain")) {
                candidates.addAll(cookies.filter { !it.expiresAt.expired() })
            }
        }
        Timber.d("Cookie loadForRequest host=$host, candidates=${candidates.size}, domains=${store.keys}")
        return candidates
    }

    fun csrf(): String {
        return store.values.flatten()
            .firstOrNull { it.name == "bili_jct" }?.value ?: ""
    }

    fun allCookies(): List<Cookie> = store.values.flatten()

    fun setCookies(cookies: List<Cookie>) {
        for (cookie in cookies) {
            val domain = cookie.domain.removePrefix(".")
            store.getOrPut(domain) { mutableListOf() }.apply {
                removeAll { it.name == cookie.name }
                add(cookie)
            }
        }
    }

    fun clear() {
        store.clear()
    }

    private fun Long.expired() = System.currentTimeMillis() > this
}
