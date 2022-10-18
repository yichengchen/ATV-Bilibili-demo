//
//  FeedViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/5/19.
//

import UIKit


class FeedViewController: UIViewController {
    let collectionVC = FeedCollectionViewController.create()
    var loading = false
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] idx in
            self?.goDetail(with: idx)
        }
        loadData()
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let pressType = presses.first?.type else { return }
        switch pressType {
        case .playPause:
            loadData()
        default:
            break
        }
    }
    
    func loadData() {
        if loading { return }
        loading = true
        requests(datas: [])
    }
    
    func requests(number: Int = 0, datas: [ApiRequest.FeedResp.Items]) {
        if number > 3 {
            self.collectionVC.displayDatas = datas
            self.loading = false
            return
        }
        ApiRequest.getFeeds(datas: datas) { items in
            self.requests(number: number + 1, datas: items)
        }
    }
    
    
    func goDetail(with indexPath: IndexPath) {
        let data = collectionVC.displayDatas[indexPath.item]
        let aid = (data as! ApiRequest.FeedResp.Items).param
        let detailVC = VideoDetailViewController.create(aid: Int(aid)!, cid: 0)
        present(detailVC, animated: true)
    }
    
    @objc func actionPlay() {
        loadData()
    }
    
}
