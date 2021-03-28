//
//  HomeViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Foundation
import UIKit

import Alamofire
import SwiftyJSON
import Kingfisher

class HomeViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    var rooms = [LiveRoom]()
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(loadData), name: .loginStateChange, object: nil)
        loadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let source = sender as? UIButton, let dist = segue.destination as? PlayerViewController {
            dist.roomID = source.tag
        }
    }
    
    @IBAction func actionReload(_ sender: Any) {
        loadData()
    }
    
    @objc func loadData() {
        AF.request("https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList").responseJSON {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                let json = JSON(data)
                self.process(json: json)
            case .failure(let err):
                print(err)
            }
        }
    }
    
    func process(json: JSON) {
        rooms = json["data"]["rooms"].arrayValue.map { room in
            LiveRoom(name: room["title"].stringValue,
                     roomID: room["room_id"].intValue,
                     up: room["uname"].stringValue,
                     cover: room["keyframe"].url)
        }
        collectionView.reloadData()
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let room = rooms[indexPath.item]
        let cid = room.roomID
        let playerVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "PlayerViewController") as! PlayerViewController
        playerVC.roomID = cid
        playerVC.updateRoomID = false
        present(playerVC, animated: true, completion: nil)
    }
    
}

extension HomeViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return rooms.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! HomeCollectionViewCell
        let room = rooms[indexPath.item]
        cell.setup(room: room)
        return cell
    }
}


class HomeCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var upLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        imageView.adjustsImageWhenAncestorFocused = true
        clipsToBounds = false
        layer.borderWidth = 4
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if isFocused {
            layer.borderColor = UIColor.red.cgColor
        } else {
            layer.borderColor = UIColor.clear.cgColor
        }
    }
    
    func setup(room: LiveRoom) {
        titleLabel.text = room.name
        upLabel.text = room.up
        imageView.kf.setImage(with:room.cover)
    }
}


struct LiveRoom {
    let name:String
    let roomID: Int
    let up: String
    let cover: URL?
}
