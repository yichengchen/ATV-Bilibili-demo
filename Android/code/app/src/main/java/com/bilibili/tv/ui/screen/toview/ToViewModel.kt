package com.bilibili.tv.ui.screen.toview

import com.bilibili.tv.data.model.ToViewData
import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.BaseVideoGridViewModel
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import com.bilibili.tv.ui.component.formatCount
import dagger.hilt.android.lifecycle.HiltViewModel
import timber.log.Timber
import javax.inject.Inject

@HiltViewModel
class ToViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : BaseVideoGridViewModel() {

    override val supportsLoadMore = false

    init { reload() }

    override suspend fun requestPage(page: Int): VideoGridPage {
        val items = feedRepository.getToView()
        Timber.d("ToView loaded: ${items.size} items")
        return VideoGridPage(items = items.toGridItems(), hasMore = false)
    }

    private fun List<ToViewData>.toGridItems() = map { item ->
        VideoGridItem(
            aid = item.aid,
            title = item.title,
            coverUrl = item.pic,
            ownerName = item.owner.name,
            avatarUrl = item.owner.face,
            playCount = formatCount(item.stat?.view ?: 0),
            danmakuCount = formatCount(item.stat?.danmaku ?: 0),
            duration = if (item.duration > 0) "%d:%02d".format(item.duration / 60, item.duration % 60) else null
        )
    }
}
