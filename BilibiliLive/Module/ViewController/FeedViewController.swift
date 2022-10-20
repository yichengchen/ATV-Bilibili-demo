//
//  FeedViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/5/19.
//

import UIKit


class FeedViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController()
    var loading = false
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] idx in
            self?.goDetail(with: idx)
        }
        
        collectionVC.loadMore = {
            [weak self] in
            self?.loadMore()
        }
        reloadData()
    }
    
    func reloadData() {
        if loading { return }
        Task {
            loading = true
            let feeds = try? await ApiRequest.getFeeds()
            collectionVC.displayDatas = feeds ?? []
            loading = false
        }
    }
    
    func loadMore() {
        guard let last = (collectionVC.displayDatas.last as? ApiRequest.FeedResp.Items)?.idx else {
            return
        }
        Task {
            loading = true
            let newData = try? await ApiRequest.getFeeds(lastIdx: last)
            collectionVC.appendData(displayData: newData ?? [])
            loading = false
        }
    }
    
    func goDetail(with indexPath: IndexPath) {
        let data = collectionVC.displayDatas[indexPath.item]
        let aid = (data as! ApiRequest.FeedResp.Items).param
        let detailVC = VideoDetailViewController.create(aid: Int(aid)!, cid: 0)
        detailVC.present(from: self)
    }
    
}
