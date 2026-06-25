package com.bilibili.tv

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import com.bilibili.tv.data.remote.CookieJarImpl
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class App : Application(), ImageLoaderFactory {

    @Inject lateinit var imageLoader: ImageLoader

    override fun onCreate() {
        super.onCreate()
        timber.log.Timber.plant(timber.log.Timber.DebugTree())
    }

    override fun newImageLoader(): ImageLoader = imageLoader
}
