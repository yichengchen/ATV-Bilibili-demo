//
//  MyUploadsViewController.swift
//  BilibiliLive
//
//  Created by Claude on 2024/11/28.
//

import Foundation
import UIKit

/// 我的投稿视频列表
class MyUploadsViewController: StandardVideoCollectionViewController<ApiRequest.UpSpaceListData> {
    private var lastAid: Int?

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 20
    }

    override func request(page: Int) async throws -> [ApiRequest.UpSpaceListData] {
        guard let mid = ApiRequest.getToken()?.mid else {
            Logger.warn("[MyUploads] User not logged in")
            return []
        }

        // 第一页时重置 lastAid
        let requestLastAid = page == 1 ? nil : lastAid

        let res = try await ApiRequest.requestUpSpaceVideo(mid: mid, lastAid: requestLastAid)

        // 只有在有结果时才更新 lastAid
        if !res.isEmpty {
            lastAid = res.last?.aid
        } else if page == 1 {
            lastAid = nil
        }

        return res
    }
}
