package com.bilibili.tv.ui.screen.detail

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.BringIntoViewSpec
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.tv.material3.Button
import androidx.tv.material3.ButtonDefaults
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.Icon
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import coil.compose.AsyncImage
import com.bilibili.tv.data.model.Replys
import com.bilibili.tv.data.model.VideoDetail
import com.bilibili.tv.ui.component.BiliImageSize
import com.bilibili.tv.ui.component.formatCount
import com.bilibili.tv.ui.component.rememberBiliImageRequest
import com.bilibili.tv.ui.theme.BiliColors

@OptIn(ExperimentalFoundationApi::class, ExperimentalTvMaterial3Api::class)
@Composable
fun VideoDetailScreen(
    aid: Long,
    onPlay: (Long, Long) -> Unit,
    onVideoClick: (Long) -> Unit,
    onBack: () -> Unit,
    viewModel: VideoDetailViewModel = hiltViewModel()
) {
    val state = viewModel.uiState
    var selectedReply by remember { mutableStateOf<Replys.Reply?>(null) }
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(aid) { viewModel.loadDetail(aid) }

    if (state.isLoading) {
        Box(Modifier.fillMaxSize().background(BiliColors.AppBackground), Alignment.Center) { CircularProgressIndicator() }
        return
    }
    if (state.error != null) {
        Box(Modifier.fillMaxSize().background(BiliColors.AppBackground), Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("加载失败: ${state.error}", color = Color.White)
                Spacer(Modifier.height(16.dp))
                Button(onClick = { viewModel.loadDetail(aid) }) { Text("重试") }
            }
        }
        return
    }

    val info = state.info ?: return
    val backgroundRequest = rememberBiliImageRequest(
        url = info.pic,
        width = BiliImageSize.DETAIL_BACKGROUND_WIDTH,
        height = BiliImageSize.DETAIL_BACKGROUND_HEIGHT
    )
    val coverRequest = rememberBiliImageRequest(
        url = info.pic,
        width = BiliImageSize.DETAIL_COVER_WIDTH,
        height = BiliImageSize.DETAIL_COVER_HEIGHT
    )
    val ownerAvatarRequest = rememberBiliImageRequest(
        url = info.owner.face,
        width = BiliImageSize.AVATAR_SMALL,
        height = BiliImageSize.AVATAR_SMALL,
        format = "jpg"
    )

    Box(Modifier.fillMaxSize().background(BiliColors.AppBackground)) {
        AsyncImage(model = backgroundRequest, contentDescription = null, modifier = Modifier.fillMaxWidth().height(400.dp).blur(30.dp), contentScale = ContentScale.Crop, alpha = 0.3f)
        Box(Modifier.fillMaxWidth().height(400.dp).background(Brush.verticalGradient(listOf(Color.Transparent, BiliColors.AppBackground))))

        CompositionLocalProvider(LocalBringIntoViewSpec provides DetailBringIntoViewSpec) {
            LazyColumn(Modifier.fillMaxSize(), state = listState, contentPadding = PaddingValues(bottom = 48.dp)) {
                // ── Header ──
                item {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(start = 48.dp, end = 48.dp, top = 60.dp)
                    ) {
                        AsyncImage(model = coverRequest, contentDescription = info.title, modifier = Modifier.width(320.dp).height(180.dp).clip(RoundedCornerShape(12.dp)), contentScale = ContentScale.Crop)
                        Spacer(Modifier.width(32.dp))
                        Column(Modifier.weight(1f)) {
                            Text(info.title, style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold, fontSize = 28.sp, lineHeight = 36.sp), color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Spacer(Modifier.height(16.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                AsyncImage(model = ownerAvatarRequest, contentDescription = null, modifier = Modifier.size(36.dp).clip(CircleShape), contentScale = ContentScale.Crop)
                                Spacer(Modifier.width(12.dp))
                                Column {
                                    Text(info.owner.name, style = MaterialTheme.typography.titleMedium, color = Color(0xFFAAAAAA))
                                    if (state.card.follower > 0) Text("${formatCount(state.card.follower)}粉丝", fontSize = 12.sp, color = Color(0xFF888888))
                                }
                            }
                            Spacer(Modifier.height(20.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                                StatItem("▶", formatCount(info.stat.view))
                                StatItem("💬", formatCount(info.stat.danmaku))
                                if (info.duration > 0) StatItem("⏱", "%d:%02d".format(info.duration / 60, info.duration % 60))
                            }
                            Spacer(Modifier.height(24.dp))
                            Button(
                                onClick = { onPlay(aid, viewModel.selectedCid) },
                                modifier = Modifier.onFocusChanged { focusState ->
                                    if (focusState.isFocused) {
                                        coroutineScope.launch { listState.scrollToItem(0, 0) }
                                    }
                                },
                                colors = ButtonDefaults.colors(containerColor = Color(0xFF00A1D6))
                            ) {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("播放", fontSize = 16.sp)
                            }
                        }
                    }
                }

                // ── Description ──
                if (!info.desc.isNullOrBlank()) {
                    item {
                        Spacer(Modifier.height(32.dp))
                        Text(info.desc, modifier = Modifier.padding(horizontal = 48.dp), style = MaterialTheme.typography.bodyLarge, color = Color(0xFFCCCCCC), lineHeight = 24.sp)
                    }
                }

                // ── Pages ──
                val pages = info.pages
                if (pages != null && pages.size > 1) {
                    item {
                        SectionTitle("分P (${pages.size}P)")
                        Spacer(Modifier.height(12.dp))
                        LazyRow(contentPadding = PaddingValues(horizontal = 48.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            items(pages) { page ->
                                val isSelected = page.cid == viewModel.selectedCid
                                Surface(onClick = { viewModel.selectPage(page.cid) }) {
                                    Text("P${page.page} ${page.part}", modifier = Modifier.background(if (isSelected) Color(0xFF00A1D6) else BiliColors.SurfaceVariant).padding(horizontal = 16.dp, vertical = 10.dp), color = if (isSelected) Color.White else Color(0xFFCCCCCC), fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                }
                            }
                        }
                    }
                }

                // ── UGC Season ──
                if (state.ugcEpisodes.isNotEmpty()) {
                    item {
                        SectionTitle("合集 · ${state.ugcTitle}")
                        Spacer(Modifier.height(12.dp))
                        LazyRow(contentPadding = PaddingValues(horizontal = 48.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            items(state.ugcEpisodes) { ep ->
                                UgcEpisodeCard(ep.title, ep.arc.pic, ep.aid == aid) { onVideoClick(ep.aid) }
                            }
                        }
                    }
                }

                // ── Related ──
                if (state.related.isNotEmpty()) {
                    item {
                        SectionTitle("相关推荐")
                        Spacer(Modifier.height(12.dp))
                        LazyRow(contentPadding = PaddingValues(horizontal = 48.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            items(state.related.take(20)) { r -> RelatedVideoCard(r) { onVideoClick(r.aid) } }
                        }
                    }
                }

                // ── Comments (卡片) ──
                if (state.replies.isNotEmpty()) {
                    item {
                        SectionTitle("评论")
                        Spacer(Modifier.height(12.dp))
                        LazyRow(contentPadding = PaddingValues(horizontal = 48.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            items(state.replies.take(10)) { reply ->
                                if (reply.content.message.isNotBlank()) CommentCard(reply) { selectedReply = reply }
                            }
                        }
                    }
                }
            }
        }
    }

    selectedReply?.let { CommentDetailDialog(it) { selectedReply = null } }
}

// ═══════════════════════════════════════════════════════

@OptIn(ExperimentalFoundationApi::class)
private object DetailBringIntoViewSpec : BringIntoViewSpec {
    override fun calculateScrollDistance(offset: Float, size: Float, containerSize: Float): Float {
        val trailingEdge = offset + size
        return when {
            offset >= 0f && trailingEdge <= containerSize -> 0f
            offset < 0f && trailingEdge > containerSize -> 0f
            kotlin.math.abs(offset) < kotlin.math.abs(trailingEdge - containerSize) -> offset
            else -> trailingEdge - containerSize
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(title, modifier = Modifier.padding(start = 48.dp, top = 32.dp), style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold), color = Color.White)
}

@Composable
private fun StatItem(icon: String, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(icon, fontSize = 14.sp)
        Text(label, fontSize = 14.sp, color = Color(0xFFAAAAAA))
    }
}

// ── Comment Card ──

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun CommentCard(reply: Replys.Reply, onClick: () -> Unit) {
    val avatarRequest = rememberBiliImageRequest(
        url = reply.member.avatar,
        width = BiliImageSize.AVATAR_SMALL,
        height = BiliImageSize.AVATAR_SMALL,
        format = "jpg"
    )

    Card(
        onClick = onClick,
        modifier = Modifier.width(300.dp),
        shape = CardDefaults.shape(RoundedCornerShape(12.dp)),
        colors = CardDefaults.colors(containerColor = BiliColors.Surface)
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                AsyncImage(model = avatarRequest, contentDescription = null, modifier = Modifier.size(28.dp).clip(CircleShape), contentScale = ContentScale.Crop)
                Spacer(Modifier.width(10.dp))
                Text(reply.member.uname, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Color(0xFF00A1D6), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.weight(1f))
                if (reply.like > 0) Text("👍 ${reply.like}", fontSize = 12.sp, color = Color(0xFF888888))
            }
            Spacer(Modifier.height(10.dp))
            Text(reply.content.message, fontSize = 14.sp, color = Color(0xFFCCCCCC), lineHeight = 20.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
            if (!reply.content.pictures.isNullOrEmpty()) {
                Spacer(Modifier.height(8.dp))
                Text("📷 ${reply.content.pictures!!.size}张图片", fontSize = 12.sp, color = Color(0xFF888888))
            }
            if (!reply.replies.isNullOrEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text("💬 ${reply.replies!!.size}条回复", fontSize = 12.sp, color = Color(0xFF888888))
            }
        }
    }
}

// ── Comment Detail Dialog ──

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun CommentDetailDialog(reply: Replys.Reply, onDismiss: () -> Unit) {
    val avatarRequest = rememberBiliImageRequest(
        url = reply.member.avatar,
        width = BiliImageSize.AVATAR_MEDIUM,
        height = BiliImageSize.AVATAR_MEDIUM,
        format = "jpg"
    )

    BackHandler(onBack = onDismiss)

    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.8f)).padding(60.dp),
        Alignment.Center
    ) {
        Card(
            onClick = onDismiss,
            shape = CardDefaults.shape(RoundedCornerShape(16.dp)),
            modifier = Modifier.fillMaxWidth(0.7f).fillMaxHeight(0.8f),
            colors = CardDefaults.colors(containerColor = BiliColors.Surface)
        ) {
            LazyColumn(Modifier.padding(32.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        AsyncImage(model = avatarRequest, contentDescription = null, modifier = Modifier.size(48.dp).clip(CircleShape), contentScale = ContentScale.Crop)
                        Spacer(Modifier.width(16.dp))
                        Column {
                            Text(reply.member.uname, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color(0xFF00A1D6))
                            if (reply.like > 0) Text("👍 ${reply.like}", fontSize = 14.sp, color = Color(0xFF888888))
                        }
                    }
                }
                item { Text(reply.content.message, fontSize = 16.sp, color = Color.White, lineHeight = 24.sp) }
                if (!reply.content.pictures.isNullOrEmpty()) {
                    items(reply.content.pictures!!) { pic ->
                        val imageRequest = rememberBiliImageRequest(
                            url = pic.imgSrc,
                            width = BiliImageSize.COMMENT_IMAGE_WIDTH,
                            height = BiliImageSize.COMMENT_IMAGE_HEIGHT
                        )
                        AsyncImage(model = imageRequest, contentDescription = null, modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)), contentScale = ContentScale.Fit)
                    }
                }
                if (!reply.replies.isNullOrEmpty()) {
                    item { Text("回复", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White) }
                    items(reply.replies!!) { sub ->
                        if (sub.content.message.isNotBlank()) {
                            val subAvatarRequest = rememberBiliImageRequest(
                                url = sub.member.avatar,
                                width = BiliImageSize.AVATAR_SMALL,
                                height = BiliImageSize.AVATAR_SMALL,
                                format = "jpg"
                            )
                            Row(Modifier.fillMaxWidth().background(BiliColors.SurfaceVariant, RoundedCornerShape(8.dp)).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                AsyncImage(model = subAvatarRequest, contentDescription = null, modifier = Modifier.size(24.dp).clip(CircleShape), contentScale = ContentScale.Crop)
                                Column(Modifier.weight(1f)) {
                                    Text(sub.member.uname, fontSize = 12.sp, color = Color(0xFF00A1D6))
                                    Spacer(Modifier.height(4.dp))
                                    Text(sub.content.message, fontSize = 13.sp, color = Color(0xFFCCCCCC))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ── UGC Episode Card ──

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun UgcEpisodeCard(title: String, coverUrl: String, isCurrent: Boolean, onClick: () -> Unit) {
    val coverRequest = rememberBiliImageRequest(
        url = coverUrl,
        width = BiliImageSize.EPISODE_COVER_WIDTH,
        height = BiliImageSize.EPISODE_COVER_HEIGHT
    )

    Card(
        onClick = onClick, modifier = Modifier.width(180.dp),
        shape = CardDefaults.shape(RoundedCornerShape(8.dp)),
        colors = CardDefaults.colors(containerColor = if (isCurrent) Color(0xFF00A1D6).copy(alpha = 0.2f) else BiliColors.Surface)
    ) {
        Column {
            AsyncImage(model = coverRequest, contentDescription = title, modifier = Modifier.fillMaxWidth().height(100.dp).clip(RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp)), contentScale = ContentScale.Crop)
            Text(title, modifier = Modifier.padding(8.dp), fontSize = 13.sp, color = if (isCurrent) Color(0xFF00A1D6) else Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
    }
}

// ── Related Video Card ──

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun RelatedVideoCard(info: VideoDetail.Info, onClick: () -> Unit) {
    val coverRequest = rememberBiliImageRequest(
        url = info.pic,
        width = BiliImageSize.RELATED_COVER_WIDTH,
        height = BiliImageSize.RELATED_COVER_HEIGHT
    )

    Card(
        onClick = onClick, modifier = Modifier.width(200.dp),
        shape = CardDefaults.shape(RoundedCornerShape(8.dp)),
        colors = CardDefaults.colors(containerColor = BiliColors.Surface)
    ) {
        Column {
            AsyncImage(model = coverRequest, contentDescription = info.title, modifier = Modifier.fillMaxWidth().height(112.dp).clip(RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp)), contentScale = ContentScale.Crop)
            Column(Modifier.padding(8.dp)) {
                Text(info.title, fontSize = 13.sp, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis, lineHeight = 18.sp)
                Spacer(Modifier.height(4.dp))
                Text(info.owner.name, fontSize = 11.sp, color = Color(0xFF888888), maxLines = 1)
            }
        }
    }
}
