package com.bilibili.tv.ui.screen.follows

import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.BaseVideoGridViewModel
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import dagger.hilt.android.lifecycle.HiltViewModel
import timber.log.Timber
import javax.inject.Inject

@HiltViewModel
class FollowsViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : BaseVideoGridViewModel() {

    private var lastOffset: Long? = null

    init {
        reload()
    }

    override fun reload() {
        lastOffset = null
        super.reload()
    }

    override suspend fun requestPage(page: Int): VideoGridPage {
        var requestPage = page
        var info = feedRepository.getFollowsFeed(offset = lastOffset, page = requestPage)
        var videoFeeds = info.videoFeeds

        while (videoFeeds.isEmpty() && info.has_more) {
            lastOffset = info.offset.toLongOrNull()
            requestPage++
            info = feedRepository.getFollowsFeed(offset = lastOffset, page = requestPage)
            videoFeeds = info.videoFeeds
        }

        Timber.d("Follows: items=${info.items.size}, videoFeeds=${videoFeeds.size}, offset=${info.offset}, has_more=${info.has_more}")
        lastOffset = info.offset.toLongOrNull()
        return VideoGridPage(
            items = videoFeeds.map { item ->
                VideoGridItem(
                    aid = item.aid,
                    key = "follow:${item.id_str}:${item.aid}",
                    title = item.title,
                    coverUrl = item.pic,
                    ownerName = item.ownerName,
                    avatarUrl = item.avatar
                )
            },
            hasMore = info.has_more,
            consumedPage = requestPage
        )
    }
}
