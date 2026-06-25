package com.bilibili.tv.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ApiResponse<T>(
    val code: Int = 0,
    val message: String = "",
    val data: T? = null,
    val ttl: Int = 1
) {
    val isSuccess: Boolean get() = code == 0
}

@Serializable
data class LoginQrResp(
    val url: String = "",
    val auth_code: String = ""
)

@Serializable
data class LoginPollResp(
    val mid: Int = 0,
    @SerialName("access_token") val accessToken: String = "",
    @SerialName("refresh_token") val refreshToken: String = "",
    @SerialName("expires_in") val expiresIn: Int = 0,
    @SerialName("token_info") val tokenInfo: TokenInfo? = null,
    @SerialName("cookie_info") val cookieInfo: CookieInfo? = null
) {
    @Serializable
    data class TokenInfo(
        val mid: Int = 0,
        @SerialName("access_token") val accessToken: String = "",
        @SerialName("refresh_token") val refreshToken: String = "",
        @SerialName("expires_in") val expiresIn: Int = 0
    )

    @Serializable
    data class CookieInfo(
        val domains: List<String> = emptyList(),
        val cookies: List<CookieItem> = emptyList()
    ) {
        @Serializable
        data class CookieItem(
            val name: String = "",
            val value: String = "",
            @SerialName("http_only") val httpOnly: Int = 0,
            val expires: Int = 0
        )
    }
}

@Serializable
data class RefreshTokenResp(
    val mid: Int = 0,
    @SerialName("access_token") val accessToken: String = "",
    @SerialName("refresh_token") val refreshToken: String = "",
    @SerialName("expires_in") val expiresIn: Int = 0,
    @SerialName("token_info") val tokenInfo: LoginPollResp.TokenInfo? = null,
    @SerialName("cookie_info") val cookieInfo: LoginPollResp.CookieInfo? = null
)
