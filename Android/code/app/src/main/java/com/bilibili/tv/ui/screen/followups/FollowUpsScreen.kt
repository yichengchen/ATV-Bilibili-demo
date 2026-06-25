package com.bilibili.tv.ui.screen.followups

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.tv.material3.Button
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import coil.compose.AsyncImage
import com.bilibili.tv.ui.component.BiliImageSize
import com.bilibili.tv.ui.component.biliSizedImageUrl
import com.bilibili.tv.ui.theme.BiliColors
import kotlinx.coroutines.launch
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope

@OptIn(ExperimentalTvMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun FollowUpsScreen(
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester,
    onUpClick: (Long) -> Unit,
    viewModel: FollowUpsViewModel = hiltViewModel()
) {
    val state = viewModel.uiState
    val gridState = rememberLazyGridState()
    val coroutineScope = rememberCoroutineScope()
    val isAtTop by remember {
        derivedStateOf {
            gridState.firstVisibleItemIndex == 0 && gridState.firstVisibleItemScrollOffset == 0
        }
    }

    BackHandler(enabled = state.items.isNotEmpty() && !isAtTop) {
        coroutineScope.launch {
            gridState.animateScrollToItem(0)
            restoreFocusRequester.requestFocus()
        }
    }

    Box(Modifier.fillMaxSize().background(BiliColors.AppBackground)) {
        if (state.isLoading && state.items.isEmpty()) {
            CircularProgressIndicator(modifier = Modifier.align(Alignment.Center).focusRequester(restoreFocusRequester))
        } else if (state.error != null && state.items.isEmpty()) {
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("加载失败: ${state.error}", color = MaterialTheme.colorScheme.error)
                Button(onClick = { viewModel.loadFollowUps() }, modifier = Modifier.focusRequester(restoreFocusRequester)) { Text("重试") }
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                state = gridState,
                contentPadding = PaddingValues(start = 32.dp, end = 32.dp, top = 24.dp, bottom = 48.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                itemsIndexed(state.items, key = { _, user -> user.mid }) { index, user ->
                    UpCard(
                        name = user.uname,
                        sign = user.sign,
                        avatarUrl = user.face,
                        onClick = { onUpClick(user.mid) },
                        modifier = Modifier
                            .then(if (index == 0) Modifier.focusRequester(restoreFocusRequester) else Modifier)
                            .then(if (index < 3) Modifier.focusProperties { up = upFocusRequester } else Modifier)
                    )
                    if (index >= state.items.size - 6) viewModel.loadMore()
                }
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun UpCard(
    name: String,
    sign: String,
    avatarUrl: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        onClick = onClick,
        modifier = modifier,
        shape = CardDefaults.shape(RoundedCornerShape(12.dp)),
        colors = CardDefaults.colors(containerColor = BiliColors.Surface)
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            AsyncImage(
                model = avatarUrl.biliSizedImageUrl(BiliImageSize.AVATAR_MEDIUM, BiliImageSize.AVATAR_MEDIUM),
                contentDescription = name,
                modifier = Modifier.size(56.dp).clip(CircleShape),
                contentScale = ContentScale.Crop
            )
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = BiliColors.TextPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(4.dp))
                Text(sign, fontSize = 13.sp, color = BiliColors.TextSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
