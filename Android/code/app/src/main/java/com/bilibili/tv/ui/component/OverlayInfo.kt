package com.bilibili.tv.ui.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import java.text.DecimalFormat

private val df = DecimalFormat("#.#")

fun formatCount(count: Long): String {
    return when {
        count >= 100_000_000 -> "${df.format(count / 100_000_000.0)}亿"
        count >= 10_000 -> "${df.format(count / 10_000.0)}万"
        else -> count.toString()
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun OverlayInfo(
    playCount: String,
    danmakuCount: String,
    duration: String? = null,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (playCount.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.PlayArrow,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = Color.White.copy(alpha = 0.9f)
                    )
                    Text(
                        text = playCount,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.9f)
                    )
                }
            }
            if (danmakuCount.isNotEmpty()) {
                Text(
                    text = "弹 $danmakuCount",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.9f)
                )
            }
        }
        if (duration != null) {
            Text(
                text = duration,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.9f)
            )
        }
    }
}
