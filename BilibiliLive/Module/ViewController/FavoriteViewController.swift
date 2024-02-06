//
//  FavoriteViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/18.
//
import Foundation
import UIKit

class FavoriteViewController: CategoryViewController {
    static let titleElementKind = "titleElementKind"

    override func viewDidLoad() {
        categories = []
        super.viewDidLoad()

        Task {
            // 用户创建的收藏夹
            let favList = try? await WebRequest.requestFavVideosList()
            if favList != nil {
                categories = favList!.map {
                    return CategoryDisplayModel(title: $0.title, contentVC: FavoriteVideoContentViewController(info: $0))
                }
            }

            // 用户收藏的订阅
            let favFolderCollectedList = try? await WebRequest.requestFavFolderCollectedList()
            if favFolderCollectedList != nil {
                favFolderCollectedList!.forEach {
                    categories.append(CategoryDisplayModel(title: $0.title, contentVC: FavoriteVideoContentViewController(info: $0)))
                }
            }

            initTypeCollectionView()
        }
    }
}

class FavoriteVideoContentViewController: StandardVideoCollectionViewController<FavData> {
    let info: FavListData
    init(info: FavListData) {
        self.info = info
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupCollectionView() {
        collectionVC.styleOverride = .sideBar
        super.setupCollectionView()
    }

    override func request(page: Int) async throws -> [FavData] {
        if info.createBySelf {
            return try await WebRequest.requestFavVideos(mid: String(info.id), page: page)
        } else {
            return try await WebRequest.requestFavSeason(seasonId: String(info.id), page: page)
        }
    }

    override func goDetail(with record: FavData) {
        if let seasonId = record.ogv?.season_id {
            VideoDetailViewController.create(seasonId: seasonId).present(from: self)
        } else {
            let vc = VideoDetailViewController.create(aid: record.id, cid: 0)
            vc.present(from: UIViewController.topMostViewController())
        }
    }
}
