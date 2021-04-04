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
        loadData()
    }
    
    @IBAction func actionReload(_ sender: Any) {
        rooms.removeAll()
        loadData()
    }
    
    func loadData(page:Int = 1, perviousPage:[LiveRoom] = []) {
        var rooms = perviousPage
        AF.request("https://api.live.bilibili.com/xlive/web-ucenter/v1/xfetter/GetWebList?page_size=10&page=\(page)").responseJSON {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case .success(let data):
                let json = JSON(data)
                rooms.append(contentsOf: self.process(json: json))
                let totalCount = json["data"]["count"].intValue
                if self.rooms.count < totalCount, page < 5 {
                    self.loadData(page: page+1,perviousPage: rooms)
                } else {
                    self.rooms = rooms
                    self.collectionView.reloadData()
                }
            case .failure(let err):
                print(err)
                if rooms.count > 0 {
                    self.rooms = rooms
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    func process(json: JSON) -> [LiveRoom] {
        let newRooms = json["data"]["rooms"].arrayValue.map { room in
            LiveRoom(name: room["title"].stringValue,
                     roomID: room["room_id"].intValue,
                     up: room["uname"].stringValue,
                     cover: room["keyframe"].url)
        }
        return newRooms
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let room = rooms[indexPath.item]
        let cid = room.roomID
        let playerVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "PlayerViewController") as! LivePlayerViewController
        playerVC.roomID = cid
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
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
        return header
    }
    
}


class HomeCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var upLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.clipsToBounds = false
        contentView.layer.shadowOffset = CGSize(width: 10, height: 10)
        contentView.layer.shadowColor = UIColor.gray.cgColor
        contentView.layer.shadowRadius = 20
        contentView.layer.shadowOpacity = 1
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations {
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } else {
                self.transform = .identity
            }
        } completion: {}
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


class BLTabBarViewController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let homeVC = viewController as? HomeViewController {
            homeVC.loadData()
        }
    }
}
