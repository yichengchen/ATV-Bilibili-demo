//
//  UpSpaceViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Foundation
import UIKit

class UpSpaceViewController: UIViewController {
    let collectionVC = FeedCollectionViewController()
    var mid: Int!
    private var page = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.pageSize = 40
        collectionVC.didSelect = {
            [weak self] idx in
            self?.goDetail(with: idx)
        }
        collectionVC.loadMore = {
            [weak self] in
            self?.loadMore()
        }
        loadData()
    }
    
    func loadData() {
        Task {
            page = 1
            let res = try? await WebRequest.requestUpSpaceVideo(mid: mid, page: 1)
            collectionVC.displayDatas = res ?? []
        }
    }
    
    func loadMore() {
        Task {
            do {
                let res = try await WebRequest.requestUpSpaceVideo(mid: mid, page: page+1)
                collectionVC.appendData(displayData: res)
                page = page + 1
            }
        }
    }
    
    func goDetail(with indexPath: IndexPath) {
        let history = collectionVC.displayDatas[indexPath.item] as! UpSpaceReq.List.VListData
        let detailVC = VideoDetailViewController.create(aid: history.aid, cid: 0)
        detailVC.present(from: self)
    }
}
