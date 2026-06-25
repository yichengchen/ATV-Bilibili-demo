package com.bilibili.tv.data.model

import kotlinx.serialization.Serializable

@Serializable
data class Account(
    val token: LoginToken,
    val profile: Profile,
    val cookies: List<StoredCookie> = emptyList(),
    val lastActiveAt: Long = 0
) {
    @Serializable
    data class Profile(
        val mid: Int,
        val username: String,
        val avatar: String = ""
    )

    @Serializable
    data class StoredCookie(
        val name: String,
        val value: String,
        val domain: String,
        val path: String = "/"
    )
}
