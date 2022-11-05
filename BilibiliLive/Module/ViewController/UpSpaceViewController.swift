//
//  UpSpaceViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Foundation
import UIKit

class UpSpaceViewController: StandardVideoCollectionViewController<UpSpaceReq.List.VListData> {
    var mid: Int!

    override func request(page: Int) async throws -> [UpSpaceReq.List.VListData] {
        return try await WebRequest.requestUpSpaceVideo(mid: mid, page: page)
    }
}
