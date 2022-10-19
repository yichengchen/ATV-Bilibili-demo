//
//  VideoDetailViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/17.
//

import Foundation
import UIKit

import Alamofire
import SwiftyJSON
import Kingfisher
import TVUIKit

class VideoDetailViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var upNameLabel: UILabel!
    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var effectContainerView: UIVisualEffectView!
    @IBOutlet weak var pageCollectionView: UICollectionView!
    @IBOutlet weak var recommandCollectionView: UICollectionView!
    private var loadingView = UIActivityIndicatorView()
    
    private var aid:Int!
    private var cid:Int!

    private var pages = [PageData]()
    private var relateds = [VideoDetail]()
    
    static func create(aid:Int, cid:Int) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: "VideoDetailViewController") as! VideoDetailViewController
        vc.aid = aid
        vc.cid = cid
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLoading()
        fetchData()
    }
    
    private func setupLoading() {
        effectContainerView.isHidden = true
        view.addSubview(loadingView)
        loadingView.color = .white
        loadingView.style = .large
        loadingView.startAnimating()
        loadingView.makeConstraintsBindToCenterOfSuperview()
    }
    
    func present(from vc:UIViewController) {
        if (!Settings.direatlyEnterVideo) {
            vc.present(self, animated: true)
        } else {
            vc.present(self, animated: false) { [self] in
                let player = VideoPlayerViewController()
                player.aid = aid
                player.cid = cid
                present(player, animated: true)
            }
        }
    }
    
    private func exit(with error:Error) {
        print(error)
        let alertVC = UIAlertController(title: "获取失败", message: nil, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alertVC, animated: true, completion: nil)
    }
    
    private func fetchData() {
        AF.request("http://api.bilibili.com/x/web-interface/view",parameters: ["aid":aid]).responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                let json = JSON(data)
                self.update(with: json)
            case .failure(let err):
                self.exit(with: err)
            }
        }
        
        WebRequest.requestRelatedVideo(aid: aid) {
            [weak self] recommands in
            self?.relateds = recommands
            self?.recommandCollectionView.reloadData()
        }
    }
    
    private func update(with json:JSON) {
        print(json)
        let data = json["data"]
        titleLabel.text = data["title"].stringValue
        upNameLabel.text = data["owner"]["name"].stringValue
        let image = URL(string: data["pic"].stringValue)
            coverImageView.kf.setImage(with: image)
            backgroundImageView.kf.setImage(with: image)
        
        var notes = [String]()
        let status = data["dynamic"].stringValue
        if status.count > 1 {
            notes.append(status)
        }
        notes.append(data["desc"].stringValue)
        noteLabel.text = notes.joined(separator: "\n")
        
        pages = data["pages"].arrayValue.map {
            PageData(cid: $0["cid"].intValue, name: $0["part"].stringValue)
        }
        collectionView.reloadData()
        if pages.count > 0 {
            let index = pages.firstIndex { $0.cid == cid } ?? 0
            collectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .left, animated: false)
        }
        loadingView.stopAnimating()
        loadingView.removeFromSuperview()
        effectContainerView.isHidden = false
        backgroundImageView.alpha = 0
        UIView.animate(withDuration: 0.25) {
            self.backgroundImageView.alpha = 1
        }
    }
}

extension VideoDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == pageCollectionView {
            let page = pages[indexPath.item]
            let player = VideoPlayerViewController()
            player.aid = aid
            player.cid = page.cid
            present(player, animated: true, completion: nil)
        } else {
            let video = relateds[indexPath.item]
            let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
            present(detailVC, animated: true, completion: nil)
        }
        
    }
}

extension VideoDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == pageCollectionView {
            return pages.count
        }
        return relateds.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        let label = cell.viewWithTag(2) as! UILabel
        if collectionView == pageCollectionView {
            let page = pages[indexPath.item]
            label.text = page.name
            return cell
        }
        let related = relateds[indexPath.row]
        let imageView = cell.viewWithTag(1) as! UIImageView
        label.text = related.title
        imageView.kf.setImage(with: URL(string: related.pic))
        return cell
    }
    
    
}

struct PageData {
    let cid: Int
    let name:String
}

class BLCardView: TVCardView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        subviews.first?.subviews.first?.subviews.last?.subviews.first?.subviews.first?.layer.cornerRadius = 12
       
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
