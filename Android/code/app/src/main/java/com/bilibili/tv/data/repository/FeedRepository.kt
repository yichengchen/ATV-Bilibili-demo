package com.bilibili.tv.data.repository

import com.bilibili.tv.data.model.ApiResponse
import com.bilibili.tv.data.model.DynamicFeedData
import com.bilibili.tv.data.model.DynamicFeedInfo
import com.bilibili.tv.data.model.FeedResp
import com.bilibili.tv.data.model.FollowingUser
import com.bilibili.tv.data.model.HistoryItem
import com.bilibili.tv.data.model.HotResp
import com.bilibili.tv.data.model.PlayUrlInfo
import com.bilibili.tv.data.model.Replys
import com.bilibili.tv.data.model.ToViewData
import com.bilibili.tv.data.model.VideoDetail
import com.bilibili.tv.data.remote.AppApi
import com.bilibili.tv.data.remote.WebApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeedRepository @Inject constructor(
    private val appApi: AppApi,
    private val webApi: WebApi,
    private val authRepository: AuthRepository
) {
    suspend fun getFeed(idx: Long? = null): FeedResp = withContext(Dispatchers.IO) {
        val resp = if (idx != null) appApi.getFeed(idx) else appApi.getFeed()
        handleApiResponse(resp)
        val result = resp.data ?: FeedResp()
        Timber.d("Feed: code=${resp.code}, items=${result.items.size}, first=${result.items.firstOrNull()?.title}")
        result
    }

    suspend fun getHot(page: Int): HotResp = withContext(Dispatchers.IO) {
        val resp = webApi.getHot(page)
        handleApiResponse(resp)
        resp.data ?: HotResp()
    }

    suspend fun getFollowsFeed(offset: Long? = null, page: Int): DynamicFeedInfo = withContext(Dispatchers.IO) {
        try {
            val resp = webApi.getFollowsFeed(page = page, offset = offset)
            Timber.d("Follows API: code=${resp.code}, message=${resp.message}, data=${resp.data != null}")
            handleApiResponse(resp)
            resp.data ?: DynamicFeedInfo()
        } catch (e: Exception) {
            Timber.e(e, "Follows API deserialize error")
            DynamicFeedInfo()
        }
    }

    suspend fun getVideoDetail(aid: Long): VideoDetail = withContext(Dispatchers.IO) {
        val resp = webApi.getVideoDetail(aid)
        Timber.d("getVideoDetail: code=${resp.code}, data=${resp.data != null}, msg=${resp.message}")
        handleApiResponse(resp)
        resp.data ?: throw RuntimeException("Video detail error: code=${resp.code} ${resp.message}")
    }

    suspend fun getReplies(aid: Long): List<Replys.Reply> = withContext(Dispatchers.IO) {
        try {
            val resp = webApi.getReplies(oid = aid)
            if (resp.isSuccess) resp.data?.replies ?: emptyList()
            else emptyList()
        } catch (e: Exception) {
            Timber.e(e, "getReplies failed")
            emptyList()
        }
    }

    suspend fun getPlayUrl(aid: Long, cid: Long, qn: Int, fnval: Int): PlayUrlInfo = withContext(Dispatchers.IO) {
        val resp = webApi.getPlayUrl(avid = aid, cid = cid, qn = qn, fnval = fnval)
        handleApiResponse(resp)
        resp.data ?: throw RuntimeException("Play URL error: ${resp.message}")
    }

    suspend fun getHistory(): List<HistoryItem> = withContext(Dispatchers.IO) {
        try {
            val resp = webApi.getHistory()
            handleApiResponse(resp)
            resp.data ?: emptyList()
        } catch (e: Exception) {
            Timber.e(e, "getHistory failed")
            emptyList()
        }
    }

    suspend fun getRanking(rid: Int = 0): List<VideoDetail.Info> = withContext(Dispatchers.IO) {
        try {
            val resp = webApi.getRanking(rid = rid)
            handleApiResponse(resp)
            resp.data?.list ?: emptyList()
        } catch (e: Exception) {
            Timber.e(e, "getRanking failed")
            emptyList()
        }
    }

    suspend fun getFollowings(mid: Long, page: Int): List<FollowingUser> = withContext(Dispatchers.IO) {
        try {
            val resp = webApi.getFollowings(vmid = mid, page = page)
            handleApiResponse(resp)
            resp.data?.list ?: emptyList()
        } catch (e: Exception) {
            Timber.e(e, "getFollowings failed")
            emptyList()
        }
    }

    suspend fun getToView(): List<ToViewData> = withContext(Dispatchers.IO) {
        try {
            val resp = webApi.getToView()
            handleApiResponse(resp)
            resp.data?.list ?: emptyList()
        } catch (e: Exception) {
            Timber.e(e, "getToView failed")
            emptyList()
        }
    }

    suspend fun getUpVideos(mid: Long, page: Int): com.bilibili.tv.data.remote.UpSpaceResp = withContext(Dispatchers.IO) {
        val resp = webApi.getUpVideos(mid = mid, page = page)
        handleApiResponse(resp)
        resp.data ?: com.bilibili.tv.data.remote.UpSpaceResp()
    }

    private suspend fun <T> handleApiResponse(resp: ApiResponse<T>) {
        when (resp.code) {
            -101 -> {
                Timber.w("Auth failure (code=-101), attempting token refresh")
                authRepository.refreshTokenIfNeeded()
            }
            -352 -> {
                Timber.w("WBI sign error (code=-352), cache may be stale")
            }
            -412 -> {
                Timber.w("Request blocked (code=-412), rate limited")
            }
        }
    }
}
