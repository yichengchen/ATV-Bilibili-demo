package com.bilibili.tv.di

import com.bilibili.tv.data.local.AccountDataStore
import com.bilibili.tv.data.remote.AppApi
import com.bilibili.tv.data.remote.AppSignBodyInterceptor
import com.bilibili.tv.data.remote.AppSignInterceptor
import com.bilibili.tv.data.remote.Constants
import com.bilibili.tv.data.remote.CookieJarImpl
import com.bilibili.tv.data.remote.CsrfInterceptor
import com.bilibili.tv.data.remote.GlobalHeadersInterceptor
import com.bilibili.tv.data.remote.PassportApi
import com.bilibili.tv.data.remote.WbiSignInterceptor
import com.bilibili.tv.data.remote.WebApi
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Named
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    @Provides
    @Singleton
    fun provideCookieJar(): CookieJarImpl = CookieJarImpl()

    @Provides
    @Singleton
    @Named("plain")
    fun providePlainOkHttpClient(cookieJar: CookieJarImpl): OkHttpClient {
        return OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .addInterceptor(GlobalHeadersInterceptor())
            .addInterceptor(CsrfInterceptor(cookieJar))
            .build()
    }

    // Passport client: POST body signing (matching iOS Alamofire URLEncoding)
    @Provides
    @Singleton
    @Named("passport")
    fun providePassportOkHttpClient(
        cookieJar: CookieJarImpl,
        accountDataStore: AccountDataStore
    ): OkHttpClient {
        val tokenProvider: () -> String? = {
            runBlocking { accountDataStore.getActiveAccount()?.token?.accessToken }
        }
        return OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .addInterceptor { chain ->
                chain.proceed(chain.request().newBuilder()
                    .header("User-Agent", Constants.USER_AGENT)
                    .header("Referer", Constants.REFERER)
                    .build())
            }
            .addInterceptor(AppSignBodyInterceptor(tokenProvider))
            .addInterceptor(HttpLoggingInterceptor { Timber.tag("AUTH").d(it) }
                .apply { level = HttpLoggingInterceptor.Level.BODY })
            .build()
    }

    // App client: GET query signing (feed API)
    @Provides
    @Singleton
    @Named("app")
    fun provideAppOkHttpClient(
        cookieJar: CookieJarImpl,
        accountDataStore: AccountDataStore
    ): OkHttpClient {
        val tokenProvider: () -> String? = {
            runBlocking { accountDataStore.getActiveAccount()?.token?.accessToken }
        }
        return OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .addInterceptor(GlobalHeadersInterceptor(tokenProvider))
            .addInterceptor(AppSignInterceptor())
            .addInterceptor(HttpLoggingInterceptor { Timber.tag("APP").d(it) }
                .apply { level = HttpLoggingInterceptor.Level.BASIC })
            .build()
    }

    // WBI client: web API (hot, follows, video detail, playurl)
    @Provides
    @Singleton
    @Named("wbi")
    fun provideWbiOkHttpClient(cookieJar: CookieJarImpl): OkHttpClient {
        return OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .addInterceptor(GlobalHeadersInterceptor())
            .addInterceptor(WbiSignInterceptor(cookieJar))
            .addInterceptor(CsrfInterceptor(cookieJar))
            .addInterceptor(HttpLoggingInterceptor { Timber.tag("WBI").d(it) }
                .apply { level = HttpLoggingInterceptor.Level.BASIC })
            .build()
    }

    @Provides
    @Singleton
    fun providePassportApi(@Named("passport") client: OkHttpClient, json: Json): PassportApi {
        return Retrofit.Builder()
            .baseUrl(Constants.BASE_URL_PASSPORT)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(PassportApi::class.java)
    }

    @Provides
    @Singleton
    fun provideWebApi(@Named("wbi") client: OkHttpClient, json: Json): WebApi {
        return Retrofit.Builder()
            .baseUrl(Constants.BASE_URL_API)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(WebApi::class.java)
    }

    @Provides
    @Singleton
    fun provideAppApi(@Named("app") client: OkHttpClient, json: Json): AppApi {
        return Retrofit.Builder()
            .baseUrl(Constants.BASE_URL_APP)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
            .create(AppApi::class.java)
    }
}
