//
//  StandardVideoCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/11/5.
//

import UIKit

protocol PlayableData: DisplayData {
    var aid: Int { get }
    var cid: Int { get }
}

class StandardVideoCollectionViewController<T: PlayableData>: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController()
    private var page = 0
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionVC.collectionView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        collectionVC.show(in: self)
        reloadData()
    }

    func setupCollectionView() {
        collectionVC.pageSize = 40
        collectionVC.didSelect = {
            [weak self] in
            self?.goDetail(with: $0 as! T)
        }
        collectionVC.loadMore = {
            [weak self] in
            self?.loadMore()
        }
    }

    func supportPullToLoad() -> Bool {
        return true
    }

    func request(page: Int) async throws -> [T] {
        return [T]()
    }

    func goDetail(with record: T) {
        let detailVC = VideoDetailViewController.create(aid: record.aid, cid: record.cid)
        detailVC.present(from: self)
    }

    func reloadData() {
        Task {
            page = 1
            do {
                let res = try await request(page: 1)
                collectionVC.displayDatas = res
            } catch let err {
                let alert = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                alert.addAction(.init(title: "Ok", style: .cancel))
                present(alert, animated: true)
            }
            updateFocusIfNeeded()
        }
    }

    // MARK: - Private

    private func loadMore() {
        guard supportPullToLoad() else { return }
        Task {
            do {
                let res = (try! await request(page: page + 1))
                collectionVC.appendData(displayData: res)
                page = page + 1
            }
        }
    }
}
