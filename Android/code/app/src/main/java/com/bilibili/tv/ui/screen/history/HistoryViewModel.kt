package com.bilibili.tv.ui.screen.history

import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.BaseVideoGridViewModel
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import com.bilibili.tv.ui.component.formatCount
import dagger.hilt.android.lifecycle.HiltViewModel
import timber.log.Timber
import javax.inject.Inject

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : BaseVideoGridViewModel() {

    override val supportsLoadMore: Boolean = false

    init {
        reload()
    }

    override suspend fun requestPage(page: Int): VideoGridPage {
        val items = feedRepository.getHistory()
        Timber.d("History loaded: ${items.size} items")

        return VideoGridPage(
            items = items.map { item ->
                val durationText = if (item.duration > 0 && item.progress > 0) {
                    "%s/%s".format(formatTime(item.progress), formatTime(item.duration))
                } else if (item.duration > 0) {
                    formatTime(item.duration)
                } else null

                VideoGridItem(
                    aid = item.aid,
                    key = "history:${item.viewAt}:${item.aid}",
                    title = item.title,
                    coverUrl = item.pic,
                    ownerName = item.owner.name,
                    avatarUrl = item.owner.face,
                    playCount = formatCount(item.stat?.view ?: 0),
                    danmakuCount = formatCount(item.stat?.danmaku ?: 0),
                    duration = durationText
                )
            },
            hasMore = false
        )
    }
}

private fun formatTime(seconds: Int): String {
    val m = seconds / 60
    val s = seconds % 60
    return "%d:%02d".format(m, s)
}
