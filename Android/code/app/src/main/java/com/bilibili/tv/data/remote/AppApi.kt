package com.bilibili.tv.data.remote

import com.bilibili.tv.data.model.ApiResponse
import com.bilibili.tv.data.model.FeedResp
import retrofit2.http.GET
import retrofit2.http.Query

interface AppApi {
    @GET("x/v2/feed/index")
    suspend fun getFeed(): ApiResponse<FeedResp>

    @GET("x/v2/feed/index")
    suspend fun getFeed(@Query("idx") idx: Long): ApiResponse<FeedResp>
}
