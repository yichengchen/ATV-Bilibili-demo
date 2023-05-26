//
//  UpSpaceViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Foundation
import UIKit

class UpSpaceViewController: StandardVideoCollectionViewController<ApiRequest.UpSpaceListData> {
    var mid: Int!

    private var lastAid: Int?
    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.pageSize = 20
    }

    override func request(page: Int) async throws -> [ApiRequest.UpSpaceListData] {
        if page == 1 { lastAid = nil }

        let res = try await ApiRequest.requestUpSpaceVideo(mid: mid, lastAid: lastAid)
        lastAid = res.last?.aid
        return res
    }
}
