//
//  F.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import Alamofire
import SwiftyJSON

class FeedViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    
    var feeds = [FeedData]()
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }
    
    func loadData() {
        AF.request("https://api.bilibili.com/x/web-feed/feed?ps=20&pn=1").responseJSON {
            [weak self] response in
            guard let self = self else { return }
            switch(response.result) {
            case .success(let data):
                let json = JSON(data)
                let datas = self.progrssData(json: json)
                self.feeds.append(contentsOf: datas)
                self.collectionView.reloadData()
            case .failure(let error):
                print(error)
                break
            }
        }
    }
    
    func progrssData(json:JSON) -> [FeedData] {
        let datas = json["data"].arrayValue.map { data -> FeedData in
            let title = data["archive"]["title"].stringValue
            let cid = data["archive"]["cid"].intValue
            let avid = data["id"].intValue
            let owner = data["archive"]["owner"]["name"].stringValue
            let pic = data["archive"]["pic"].url!
            return FeedData(title: title, cid: cid, aid: avid, owner: owner, pic: pic)
        }
        return datas
    }
    
}


extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feed = feeds[indexPath.item]
        let player = VideoPlayerViewController()
        player.aid = feed.aid
        player.cid = feed.cid
        present(player, animated: true, completion: nil)
    }
}

extension FeedViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return feeds.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! HomeCollectionViewCell
        let feed = feeds[indexPath.item]
        cell.titleLabel.text = feed.title
        cell.upLabel.text = feed.owner
        cell.imageView.kf.setImage(with: feed.pic)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
        return header
    }
}

struct FeedData {
    let title: String
    let cid: Int
    let aid: Int
    let owner: String
    let pic: URL
}



