//
//  DouyuCateViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/4/5.
//

import Foundation

struct DouCategoryInfo {
    let name: String
    let cateID: String

    static let all = [
        //        DouCategoryInfo(name: "星势力", cateID: "21"),
        DouCategoryInfo(name: "网游竞技", cateID: "1"),
        DouCategoryInfo(name: "单机热游", cateID: "15"),
        DouCategoryInfo(name: "手游休闲", cateID: "9"),
        DouCategoryInfo(name: "娱乐天地", cateID: "2"),
        DouCategoryInfo(name: "颜值", cateID: "8"),
    ]
}

class DouyuCateViewController: CategoryViewController {
    override func viewDidLoad() {
        categories = DouCategoryInfo.all
            .map {
                CategoryDisplayModel(title: $0.name, contentVC: DouyuAreaViewController(cateID: $0.cateID))
            }
        super.viewDidLoad()
    }
}

class DouyuAreaViewController: StandardVideoCollectionViewController<DLiveRoom> {
    let cateID: String
    init(cateID: String) {
        self.cateID = cateID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        super.setupCollectionView()
        collectionVC.styleOverride = .sideBar
        collectionVC.pageSize = 10
        reloadInterval = 15 * 60
    }

    override func request(page: Int) async throws -> [DLiveRoom] {
        return try await DouyuRequest.requestLives(channel: cateID, page: page)
    }

    override func goDetail(with record: DLiveRoom) {
        let playerVC = DouyuLivePlayerViewController(id: Int(record.room_id)!)
//        playerVC.room = record.toLiveRoom()
        present(playerVC, animated: true, completion: nil)
    }
}
