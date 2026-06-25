package com.bilibili.tv.ui.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import coil.compose.AsyncImage
import com.bilibili.tv.ui.theme.BiliColors

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun VideoCard(
    title: String,
    coverUrl: String?,
    ownerName: String,
    avatarUrl: String? = null,
    playCount: String = "",
    danmakuCount: String = "",
    duration: String? = null,
    badge: String? = null,
    badgeColor: Color = Color(0xFFFB7299),
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coverRequest = rememberBiliImageRequest(
        url = coverUrl,
        width = BiliImageSize.CARD_COVER_WIDTH,
        height = BiliImageSize.CARD_COVER_HEIGHT
    )
    val avatarRequest = rememberBiliImageRequest(
        url = avatarUrl,
        width = BiliImageSize.AVATAR_SMALL,
        height = BiliImageSize.AVATAR_SMALL,
        format = "jpg"
    )

    Card(
        onClick = onClick,
        modifier = modifier.width(280.dp),
        shape = CardDefaults.shape(shape = RoundedCornerShape(12.dp)),
        colors = CardDefaults.colors(
            containerColor = BiliColors.Surface,
            focusedContainerColor = BiliColors.SurfaceFocused
        )
    ) {
        Column {
            // Cover image with overlay
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
            ) {
                AsyncImage(
                    model = coverRequest,
                    contentDescription = title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )

                // Bottom gradient overlay
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .align(Alignment.BottomCenter)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f))
                            )
                        )
                )

                // Overlay info (play count, danmaku, duration)
                OverlayInfo(
                    playCount = playCount,
                    danmakuCount = danmakuCount,
                    duration = duration,
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                )

                // Badge (top-right corner)
                if (badge != null) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .background(
                                badgeColor,
                                shape = RoundedCornerShape(bottomStart = 8.dp)
                            )
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            badge,
                            color = Color.White,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            // Title + owner info
            Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontWeight = FontWeight.Medium,
                        fontSize = 15.sp,
                        lineHeight = 20.sp
                    ),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (avatarUrl != null) {
                        AsyncImage(
                            model = avatarRequest,
                            contentDescription = null,
                            modifier = Modifier
                                .size(24.dp)
                                .clip(CircleShape),
                            contentScale = ContentScale.Crop
                        )
                    }
                    Text(
                        text = ownerName,
                        style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                        color = Color(0xFFAAAAAA),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}
