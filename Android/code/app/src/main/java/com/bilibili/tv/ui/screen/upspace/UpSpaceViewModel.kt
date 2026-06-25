package com.bilibili.tv.ui.screen.upspace

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bilibili.tv.data.model.VideoDetail
import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import com.bilibili.tv.ui.component.formatCount
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject

@HiltViewModel
class UpSpaceViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : com.bilibili.tv.ui.component.BaseVideoGridViewModel() {

    private var _mid = 0L

    fun initMid(value: Long) {
        if (_mid != value) {
            _mid = value
            reload()
        }
    }

    override suspend fun requestPage(page: Int): VideoGridPage = withContext(Dispatchers.IO) {
        try {
            val resp = feedRepository.getUpVideos(_mid, page)
            val items = resp.list?.vlist?.map { it.toGridItem() } ?: emptyList()
            val total = resp.page?.count ?: 0
            Timber.d("UpSpace: page=$page, items=${items.size}, total=$total")
            VideoGridPage(items = items, hasMore = page * 20 < total)
        } catch (e: Exception) {
            Timber.e(e, "UpSpace failed")
            VideoGridPage(items = emptyList(), hasMore = false)
        }
    }

    private fun VideoDetail.Info.toGridItem() = VideoGridItem(
        aid = aid,
        title = title,
        coverUrl = pic,
        ownerName = owner.name,
        avatarUrl = owner.face,
        playCount = formatCount(stat.view),
        danmakuCount = formatCount(stat.danmaku),
        duration = if (duration > 0) "%d:%02d".format(duration / 60, duration % 60) else null
    )
}
