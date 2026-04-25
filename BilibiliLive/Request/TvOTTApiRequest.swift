//
//  TvOTTApiRequest.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/9.
//

import Alamofire
import Foundation

struct TvOTTAutonomyResponse: Decodable {
    struct Card: Decodable, Hashable {
        let cardType: String?
        let cardGoto: String?
        let jumpId: Int?
        let cover: URL?
        let title: String?
        let uri: String?
    }

    let code: Int
    let message: String
    let ttl: Int?
    let data: [Card]?
}

struct TvOTTMainRecommendResponse: Decodable {
    struct Section: Decodable {
        struct Body: Decodable, Hashable {
            let title: String?
            let cover: URL?
            let uri: String?
            let param: String?
            let goto: String?
            let play: Int?
            let danmaku: Int?
            let duration: Int?
            let name: String?
        }

        let param: String?
        let type: String?
        let style: String?
        let title: String?
        let body: [Body]?
    }

    let code: Int
    let message: String
    let ttl: Int?
    let data: [Section]?
}

enum TvOTTApiRequest {
    enum EndPoint {
        static let autonomyIndex = "https://app.bilibili.com/x/ott/autonomy/index"
        static let mainRecommendFallback = "http://app.bilibili.com/x/v2/show"
    }

    static func requestAutonomyIndex() async throws -> TvOTTAutonomyResponse {
        // Current app accounts are logged in via the iPhone appkey group.
        // Reusing that token on TV-signed requests triggers -663 auth failures.
        let accessKey: String? = nil
        guard let url = TvOTTSigner.signedURL(endpoint: EndPoint.autonomyIndex, accessKey: accessKey) else {
            throw RequestError.decodeFail(message: "无法构建 OTT 推荐请求 URL")
        }

        #if DEBUG
            if ApiRequest.getToken() != nil {
                Logger.warn("[TVOTT] skip shared access token for OTT request to avoid -663 auth failure")
            }
            Logger.debug("[TVOTT] request autonomy index endpoint=\(EndPoint.autonomyIndex) auth=\(accessKey != nil)")
        #endif

        let headers: HTTPHeaders = [
            .userAgent(TvOTTSigner.userAgent),
            HTTPHeader(name: "Referer", value: Keys.referer),
        ]

        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, headers: headers)
                .validate(statusCode: 200..<300)
                .responseDecodable(of: TvOTTAutonomyResponse.self, decoder: makeDecoder()) { response in
                    switch response.result {
                    case let .success(payload):
                        guard payload.code == 0 else {
                            #if DEBUG
                                Logger.warn("[TVOTT] autonomy index failed code=\(payload.code) message=\(payload.message)")
                            #endif
                            continuation.resume(throwing: RequestError.statusFail(code: payload.code, message: payload.message))
                            return
                        }

                        #if DEBUG
                            let cards = payload.data ?? []
                            let ugcCount = cards.filter { $0.cardType == "small_popular_ugc" && ($0.jumpId ?? 0) > 0 }.count
                            Logger.debug("[TVOTT] autonomy index cards=\(cards.count) ugc=\(ugcCount)")
                        #endif

                        continuation.resume(returning: payload)
                    case let .failure(error):
                        let requestError: RequestError
                        if let statusCode = response.response?.statusCode {
                            requestError = .statusFail(code: statusCode, message: error.localizedDescription)
                        } else {
                            requestError = .networkFail
                        }
                        #if DEBUG
                            Logger.warn("[TVOTT] autonomy index request failed: \(error)")
                        #endif
                        continuation.resume(throwing: requestError)
                    }
                }
        }
    }

    static func requestMainRecommendFallback() async throws -> TvOTTMainRecommendResponse {
        guard let url = TvOTTSigner.signedURL(endpoint: EndPoint.mainRecommendFallback) else {
            throw RequestError.decodeFail(message: "无法构建 OTT 推荐兜底请求 URL")
        }

        #if DEBUG
            Logger.debug("[TVOTT] request fallback recommend endpoint=\(EndPoint.mainRecommendFallback)")
        #endif

        let headers: HTTPHeaders = [
            .userAgent(TvOTTSigner.userAgent),
            HTTPHeader(name: "Referer", value: Keys.referer),
        ]

        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get, headers: headers)
                .validate(statusCode: 200..<300)
                .responseDecodable(of: TvOTTMainRecommendResponse.self, decoder: makeDecoder()) { response in
                    switch response.result {
                    case let .success(payload):
                        guard payload.code == 0 else {
                            #if DEBUG
                                Logger.warn("[TVOTT] fallback recommend failed code=\(payload.code) message=\(payload.message)")
                            #endif
                            continuation.resume(throwing: RequestError.statusFail(code: payload.code, message: payload.message))
                            return
                        }

                        #if DEBUG
                            let recommendCount = (payload.data ?? [])
                                .filter { $0.type == "recommend" }
                                .flatMap { $0.body ?? [] }
                                .filter { $0.goto == "av" }
                                .count
                            Logger.debug("[TVOTT] fallback recommend sections=\((payload.data ?? []).count) items=\(recommendCount)")
                        #endif

                        continuation.resume(returning: payload)
                    case let .failure(error):
                        let requestError: RequestError
                        if let statusCode = response.response?.statusCode {
                            requestError = .statusFail(code: statusCode, message: error.localizedDescription)
                        } else {
                            requestError = .networkFail
                        }
                        #if DEBUG
                            Logger.warn("[TVOTT] fallback recommend request failed: \(error)")
                        #endif
                        continuation.resume(throwing: requestError)
                    }
                }
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
