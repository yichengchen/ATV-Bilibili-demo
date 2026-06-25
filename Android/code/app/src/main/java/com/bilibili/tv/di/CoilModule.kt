package com.bilibili.tv.di

import android.content.Context
import coil.ImageLoader
import coil.disk.DiskCache
import coil.memory.MemoryCache
import coil.request.CachePolicy
import coil.size.Precision
import com.bilibili.tv.data.remote.CookieJarImpl
import com.bilibili.tv.data.remote.GlobalHeadersInterceptor
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object CoilModule {

    @Provides
    @Singleton
    fun provideImageLoader(
        @ApplicationContext context: Context,
        cookieJar: CookieJarImpl
    ): ImageLoader {
        val okHttpClient = OkHttpClient.Builder()
            .cookieJar(cookieJar)
            .addInterceptor(GlobalHeadersInterceptor())
            .build()

        return ImageLoader.Builder(context)
            .okHttpClient(okHttpClient)
            .diskCachePolicy(CachePolicy.ENABLED)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .allowRgb565(true)
            .precision(Precision.INEXACT)
            .memoryCache {
                MemoryCache.Builder(context)
                    .maxSizePercent(0.15)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(context.cacheDir.resolve("image_cache"))
                    .maxSizePercent(0.02)
                    .build()
            }
            .crossfade(true)
            .build()
    }
}
