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
    var lastReloadDate = Date()
    var reloadInterval: TimeInterval = 60 * 60
    var reloading = false
    private var page = 0
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionVC.collectionView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        collectionVC.show(in: self)
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autoReloadIfNeed()
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
            await reallyReloadData()
        }
    }

    func reallyReloadData() async {
        if reloading { return }
        reloading = true
        defer {
            reloading = false
        }
        lastReloadDate = Date()
        page = 1
        do {
            let res = try await request(page: 1)
            collectionVC.displayDatas = res
        } catch let err {
            let alert = UIAlertController(title: "Error", message: "\(err)", preferredStyle: .alert)
            alert.addAction(.init(title: "Ok", style: .cancel))
            present(alert, animated: true)
        }
    }

    // MARK: - Private

    private func loadMore() {
        guard supportPullToLoad() else { return }
        Task {
            do {
                if let res = (try? await request(page: page + 1)) {
                    collectionVC.appendData(displayData: res)
                    page = page + 1
                }
            }
        }
    }

    func autoReloadIfNeed() {
        guard isViewLoaded, view.window != nil else { return }
        guard Date().timeIntervalSince(lastReloadDate) > reloadInterval else { return }
        Task {
            await reallyReloadData()
        }
    }

    @objc private func didBecomeActive() {
        autoReloadIfNeed()
    }
}
