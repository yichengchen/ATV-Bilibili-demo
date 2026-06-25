package com.bilibili.tv.ui.screen.feed

import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.BaseVideoGridViewModel
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class FeedViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : BaseVideoGridViewModel() {

    private var lastIdx: Long? = null

    init {
        reload()
    }

    override fun reload() {
        lastIdx = null
        super.reload()
    }

    override suspend fun requestPage(page: Int): VideoGridPage {
        val resp = feedRepository.getFeed(idx = lastIdx)
        lastIdx = resp.items.lastOrNull()?.idx
        return VideoGridPage(
            items = resp.items.map { item ->
                VideoGridItem(
                    aid = item.aid,
                    key = "feed:${item.idx}:${item.aid}",
                    title = item.title,
                    coverUrl = item.cover,
                    ownerName = item.ownerName,
                    avatarUrl = item.avatarUrl,
                    playCount = item.viewDisplay,
                    danmakuCount = item.danmakuDisplay
                )
            },
            hasMore = resp.items.isNotEmpty()
        )
    }
}
