package com.bilibili.tv.data.repository

import com.bilibili.tv.data.local.AccountDataStore
import com.bilibili.tv.data.model.Account
import com.bilibili.tv.data.model.LoginPollResp
import com.bilibili.tv.data.model.LoginToken
import com.bilibili.tv.data.remote.CookieJarImpl
import com.bilibili.tv.data.remote.PassportApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Cookie
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

enum class LoginState {
    Success, Waiting, Expired, Failed
}

@Singleton
class AuthRepository @Inject constructor(
    private val passportApi: PassportApi,
    private val accountDataStore: AccountDataStore,
    private val cookieJar: CookieJarImpl
) {
    suspend fun getLoginQrCode(): Pair<String, String> = withContext(Dispatchers.IO) {
        val resp = passportApi.getLoginQrCode()
        if (resp.isSuccess && resp.data != null) {
            resp.data.auth_code to resp.data.url
        } else {
            throw RuntimeException("Failed to get QR code: ${resp.message}")
        }
    }

    suspend fun pollLogin(authCode: String): LoginState = withContext(Dispatchers.IO) {
        try {
            val resp = passportApi.pollLoginQr(authCode)
            Timber.d("Login poll: code=${resp.code}")
            when (resp.code) {
                0 -> {
                    val data = resp.data ?: return@withContext LoginState.Failed
                    val tokenInfo = data.tokenInfo
                    val token = if (tokenInfo != null) {
                        LoginToken(
                            mid = tokenInfo.mid,
                            accessToken = tokenInfo.accessToken,
                            refreshToken = tokenInfo.refreshToken,
                            expiresIn = tokenInfo.expiresIn,
                            expireDate = System.currentTimeMillis() + tokenInfo.expiresIn * 1000L
                        )
                    } else {
                        LoginToken(
                            mid = data.mid,
                            accessToken = data.accessToken,
                            refreshToken = data.refreshToken,
                            expiresIn = data.expiresIn,
                            expireDate = System.currentTimeMillis() + data.expiresIn * 1000L
                        )
                    }

                    // Save cookies from login response cookieInfo
                    val savedCount = saveCookieInfo(data.cookieInfo)
                    Timber.d("Login: saved $savedCount cookies from cookieInfo")

                    // If no cookies from cookieInfo, try refresh to get them
                    if (savedCount == 0) {
                        refreshTokenAndSaveCookies(token)
                    }

                    // Save account
                    saveAccount(token)
                    LoginState.Success
                }
                86039 -> LoginState.Waiting
                86038 -> LoginState.Expired
                86090 -> LoginState.Waiting
                else -> LoginState.Failed
            }
        } catch (e: Exception) {
            Timber.e(e, "Login poll failed")
            LoginState.Failed
        }
    }

    private fun saveCookieInfo(cookieInfo: LoginPollResp.CookieInfo?): Int {
        if (cookieInfo == null) return 0
        val domains = cookieInfo.domains
        if (domains.isEmpty() || cookieInfo.cookies.isEmpty()) return 0

        val cookies = cookieInfo.cookies.flatMap { c ->
            domains.map { domain ->
                Cookie.Builder()
                    .domain(domain.removePrefix("."))
                    .path("/")
                    .name(c.name)
                    .value(c.value)
                    .expiresAt(if (c.expires > 0) c.expires * 1000L else Long.MAX_VALUE)
                    .build()
            }
        }
        cookieJar.setCookies(cookies)
        return cookies.size
    }

    private suspend fun refreshTokenAndSaveCookies(currentToken: LoginToken) {
        try {
            val resp = passportApi.refreshToken(currentToken.refreshToken)
            Timber.d("Refresh for cookies: code=${resp.code}")
            if (resp.isSuccess) {
                resp.data?.cookieInfo?.let { saveCookieInfo(it) }
            }
        } catch (e: Exception) {
            Timber.e(e, "Refresh for cookies failed")
        }
    }

    private suspend fun saveAccount(token: LoginToken) {
        val cookies = cookieJar.allCookies().map { c ->
            Account.StoredCookie(
                name = c.name, value = c.value,
                domain = c.domain, path = c.path
            )
        }
        val account = Account(
            token = token,
            profile = Account.Profile(mid = token.mid, username = "UID ${token.mid}", avatar = ""),
            cookies = cookies,
            lastActiveAt = System.currentTimeMillis()
        )
        accountDataStore.upsertAccount(account)
        Timber.d("Account saved: UID ${token.mid}, cookies=${cookies.size}")
    }

    suspend fun refreshTokenIfNeeded() {
        val account = accountDataStore.getActiveAccount() ?: return
        val token = account.token
        val tokenExpired = token.expireDate <= System.currentTimeMillis() + 60_000
        val noCookies = cookieJar.allCookies().isEmpty()

        // Always refresh if token expired OR no cookies
        if (!tokenExpired && !noCookies) return

        try {
            Timber.d("Refreshing token (expired=$tokenExpired, noCookies=$noCookies)...")
            val resp = passportApi.refreshToken(token.refreshToken)
            if (resp.isSuccess && resp.data != null) {
                val data = resp.data
                val tokenInfo = data.tokenInfo
                val newToken = if (tokenInfo != null) {
                    LoginToken(
                        mid = tokenInfo.mid,
                        accessToken = tokenInfo.accessToken,
                        refreshToken = tokenInfo.refreshToken,
                        expiresIn = tokenInfo.expiresIn,
                        expireDate = System.currentTimeMillis() + tokenInfo.expiresIn * 1000L
                    )
                } else {
                    LoginToken(
                        mid = data.mid,
                        accessToken = data.accessToken,
                        refreshToken = data.refreshToken,
                        expiresIn = data.expiresIn,
                        expireDate = System.currentTimeMillis() + data.expiresIn * 1000L
                    )
                }

                val savedCount = saveCookieInfo(data.cookieInfo)
                Timber.d("Token refreshed: cookies=$savedCount, newExpiry=${newToken.expireDate}")

                // Save updated account with new token and cookies
                val updatedCookies = cookieJar.allCookies().map { c ->
                    Account.StoredCookie(name = c.name, value = c.value, domain = c.domain, path = c.path)
                }
                accountDataStore.upsertAccount(account.copy(
                    token = newToken,
                    cookies = updatedCookies,
                    lastActiveAt = System.currentTimeMillis()
                ))
            } else {
                Timber.w("Token refresh failed: code=${resp.code}, message=${resp.message}")
                // If refresh fails with auth error, clear account and force re-login
                if (resp.code == -101) {
                    Timber.w("Refresh token invalid, clearing account")
                    accountDataStore.clear()
                    cookieJar.clear()
                }
            }
        } catch (e: Exception) {
            Timber.e(e, "Token refresh error")
        }
    }

    suspend fun loadAccountCookies(): Boolean {
        val account = accountDataStore.getActiveAccount() ?: return false

        if (account.cookies.isNotEmpty()) {
            val cookies = account.cookies.map { sc ->
                Cookie.Builder()
                    .domain(sc.domain.removePrefix("."))
                    .path(sc.path)
                    .name(sc.name)
                    .value(sc.value)
                    .build()
            }
            cookieJar.setCookies(cookies)
            Timber.d("Restored ${cookies.size} cookies from storage")
        }

        refreshTokenIfNeeded()
        return accountDataStore.getActiveAccount() != null
    }

    suspend fun isLoggedIn(): Boolean = accountDataStore.isLoggedIn()

    suspend fun logout() {
        val account = accountDataStore.getActiveAccount() ?: return
        accountDataStore.removeAccount(account.profile.mid)
        cookieJar.clear()
    }
}
