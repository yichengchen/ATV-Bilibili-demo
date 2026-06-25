package com.bilibili.tv.data.remote

import com.bilibili.tv.data.model.ApiResponse
import com.bilibili.tv.data.model.DynamicFeedInfo
import com.bilibili.tv.data.model.FollowingUser
import com.bilibili.tv.data.model.HistoryItem
import com.bilibili.tv.data.model.HotResp
import com.bilibili.tv.data.model.NavInfo
import com.bilibili.tv.data.model.PlayUrlInfo
import com.bilibili.tv.data.model.Replys
import com.bilibili.tv.data.model.ToViewData
import com.bilibili.tv.data.model.VideoDetail
import retrofit2.http.GET
import retrofit2.http.Query

interface WebApi {
    @GET("x/web-interface/popular")
    suspend fun getHot(
        @Query("pn") page: Int,
        @Query("ps") pageSize: Int = 40
    ): ApiResponse<HotResp>

    @GET("x/polymer/web-dynamic/v1/feed/all")
    suspend fun getFollowsFeed(
        @Query("type") type: String = "all",
        @Query("timezone_offset") tz: String = "-480",
        @Query("page") page: Int,
        @Query("offset") offset: Long? = null
    ): ApiResponse<DynamicFeedInfo>

    @GET("x/web-interface/view/detail")
    suspend fun getVideoDetail(@Query("aid") aid: Long): ApiResponse<VideoDetail>

    @GET("x/player/wbi/playurl")
    suspend fun getPlayUrl(
        @Query("avid") avid: Long,
        @Query("cid") cid: Long,
        @Query("qn") qn: Int,
        @Query("fnval") fnval: Int,
        @Query("fourk") fourk: Int = 1
    ): ApiResponse<PlayUrlInfo>

    @GET("x/v2/reply")
    suspend fun getReplies(
        @Query("type") type: Int = 1,
        @Query("oid") oid: Long,
        @Query("sort") sort: Int = 1,
        @Query("nohot") nohot: Int = 0
    ): ApiResponse<Replys>

    @GET("x/v2/history")
    suspend fun getHistory(): ApiResponse<List<HistoryItem>>

    @GET("x/web-interface/ranking/v2")
    suspend fun getRanking(
        @Query("rid") rid: Int = 0,
        @Query("type") type: String = "all"
    ): ApiResponse<RankResp>

    @GET("x/relation/followings")
    suspend fun getFollowings(
        @Query("vmid") vmid: Long,
        @Query("order_type") orderType: String = "attention",
        @Query("pn") page: Int,
        @Query("ps") pageSize: Int = 40
    ): ApiResponse<FollowingsResp>

    @GET("x/v2/history/toview")
    suspend fun getToView(): ApiResponse<ToViewResp>

    @GET("x/space/wbi/arc/search")
    suspend fun getUpVideos(
        @Query("mid") mid: Long,
        @Query("pn") page: Int,
        @Query("ps") pageSize: Int = 20,
        @Query("order") order: String = "pubdate"
    ): ApiResponse<UpSpaceResp>

    @GET("x/web-interface/nav")
    suspend fun getNavInfo(): ApiResponse<NavInfo>
}

@kotlinx.serialization.Serializable
data class RankResp(val list: List<VideoDetail.Info> = emptyList())

@kotlinx.serialization.Serializable
data class FollowingsResp(val list: List<FollowingUser> = emptyList())

@kotlinx.serialization.Serializable
data class ToViewResp(val list: List<ToViewData>? = null)

@kotlinx.serialization.Serializable
data class UpSpaceResp(
    val list: UpSpaceList? = null,
    val page: UpSpacePage? = null
) {
    @kotlinx.serialization.Serializable
    data class UpSpaceList(val vlist: List<VideoDetail.Info> = emptyList())

    @kotlinx.serialization.Serializable
    data class UpSpacePage(val count: Int = 0, val pn: Int = 1, val ps: Int = 20)
}
