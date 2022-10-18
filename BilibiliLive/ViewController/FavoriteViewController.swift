//
//  FavoriteViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/18.
//

import UIKit
import SwiftyJSON

class FavoriteViewController: UIViewController {
    
    static func create() -> FavoriteViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: String(describing: self)) as! FavoriteViewController
    }
    
    @IBOutlet weak var tableView: UITableView!
    var data: [JSON]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        WebRequest.requestFavVideos { [weak self] response in
            switch response {
            case .success(let json):
                self?.data = json["list"].array
                self?.tableView.reloadData()
            case .failure(_):
                break
            }
        }
    }

}

extension FavoriteViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

extension FavoriteViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let json = data?[indexPath.row] else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: FavRowCell.self)) as! FavRowCell
        cell.titleLabel.text = json["title"].string
        cell.mid = json["id"].stringValue
        cell.reload()
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 521
    }
}

class FavRowCell: UITableViewCell {
    var mid: String!
    var data: [JSON]?
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    func reload() {
        WebRequest.requestJSON(url: "http://api.bilibili.com/x/v3/fav/resource/list", parameters: ["media_id": mid!, "ps": "20"]) { [weak self] response in
            switch response {
            case .success(let json):
                self?.data = json["medias"].array
                self?.collectionView.reloadData()
                break
            case .failure(_):
                break
            }
        }
    }
}

extension FavRowCell: UICollectionViewDelegate {
    
}

extension FavRowCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let d = data?[indexPath.row] else { return UICollectionViewCell() }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: HomeCollectionViewCell.self), for: indexPath) as! HomeCollectionViewCell
        let display = FavData(title: d["title"].stringValue, owner: d["upper"]["name"].stringValue, pic: URL(string: d["cover"].stringValue))
        cell.setup(data: display)
        return cell
    }
}

struct FavData: DisplayData {
    var title: String
    var owner: String
    var pic: URL?
}
