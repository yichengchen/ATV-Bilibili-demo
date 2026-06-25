package com.bilibili.tv

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.bilibili.tv.data.repository.AuthRepository
import com.bilibili.tv.ui.navigation.AppNavigation
import com.bilibili.tv.ui.theme.BiliTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit var authRepository: AuthRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            BiliTheme {
                AppNavigation(authRepository = authRepository)
            }
        }
    }
}
