package com.bilibili.tv.data.remote

import com.bilibili.tv.data.model.ApiResponse
import com.bilibili.tv.data.model.LoginPollResp
import com.bilibili.tv.data.model.LoginQrResp
import com.bilibili.tv.data.model.RefreshTokenResp
import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.POST

interface PassportApi {
    @FormUrlEncoded
    @POST("x/passport-tv-login/qrcode/auth_code")
    suspend fun getLoginQrCode(
        @Field("local_id") localId: String = "0"
    ): ApiResponse<LoginQrResp>

    @FormUrlEncoded
    @POST("x/passport-tv-login/qrcode/poll")
    suspend fun pollLoginQr(
        @Field("auth_code") authCode: String
    ): ApiResponse<LoginPollResp>

    @FormUrlEncoded
    @POST("api/v2/oauth2/refresh_token")
    suspend fun refreshToken(
        @Field("refresh_token") refreshToken: String
    ): ApiResponse<RefreshTokenResp>
}
