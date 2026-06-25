package com.bilibili.tv.ui.screen.login

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.tv.material3.Button
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
    viewModel: LoginViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsState()

    LaunchedEffect(state.isSuccess) {
        if (state.isSuccess) onLoginSuccess()
    }

    Row(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(48.dp)
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            if (state.qrUrl.isNotEmpty()) {
                val qrBitmap = remember(state.qrUrl) { generateQrBitmap(state.qrUrl, 400) }
                Box(
                    modifier = Modifier
                        .size(320.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(androidx.compose.ui.graphics.Color.White)
                        .padding(24.dp)
                ) {
                    if (qrBitmap != null) {
                        Image(
                            bitmap = qrBitmap.asImageBitmap(),
                            contentDescription = "QR Code",
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }
                Spacer(modifier = Modifier.height(32.dp))
                Button(onClick = { viewModel.generateQrCode() }) {
                    Text("重新生成二维码")
                }
            } else if (state.isLoading) {
                Text("正在生成二维码...", color = MaterialTheme.colorScheme.onSurface)
            } else {
                Text(state.status, color = MaterialTheme.colorScheme.error)
                Spacer(modifier = Modifier.height(16.dp))
                Button(onClick = { viewModel.generateQrCode() }) {
                    Text("重试")
                }
            }
        }

        Box(
            modifier = Modifier
                .width(1.dp)
                .fillMaxHeight()
                .background(androidx.compose.ui.graphics.Color(0xFF333333))
        )

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(start = 80.dp),
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "账号登录",
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.height(32.dp))
            Text(
                text = "1. 请打开BiliBili官方手机客户端扫码登录\n\n2. 如果登录失败尝试点击重新生成二维码",
                style = MaterialTheme.typography.bodyLarge.copy(fontSize = 18.sp),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                lineHeight = 28.sp
            )
            if (state.status.isNotEmpty() && !state.isSuccess) {
                Spacer(modifier = Modifier.height(24.dp))
                Text(
                    text = state.status,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

private fun generateQrBitmap(content: String, size: Int): Bitmap? {
    return try {
        val bitMatrix = com.google.zxing.qrcode.QRCodeWriter().encode(
            content,
            com.google.zxing.BarcodeFormat.QR_CODE,
            size,
            size,
            mapOf(com.google.zxing.EncodeHintType.MARGIN to 1)
        )
        val pixels = IntArray(size * size)
        for (y in 0 until size) {
            for (x in 0 until size) {
                pixels[y * size + x] = if (bitMatrix.get(x, y)) Color.BLACK else Color.WHITE
            }
        }
        Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
    } catch (e: Exception) {
        null
    }
}
