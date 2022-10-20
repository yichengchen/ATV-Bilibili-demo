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
    var data: [FavListData]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            data = try? await WebRequest.requestFavVideosList()
            tableView.reloadData()
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
        guard let data = data?[indexPath.row] else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: FavRowCell.self)) as! FavRowCell
        cell.titleLabel.text = data.title
        cell.mid = String(data.id)
        cell.reload()
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 521
    }
}

class FavRowCell: UITableViewCell {
    var mid: String!
    var data: [FavData]?
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(FeedCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: FeedCollectionViewCell.self))
    }
    func reload() {
        Task {
            data = try? await WebRequest.requestFavVideos(mid: mid)
            collectionView.reloadData()
        }
    }
}

extension FavRowCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let d = data?[indexPath.row] else { return }
        let vc = VideoDetailViewController.create(aid: d.id, cid: 0)
        vc.present(from: UIViewController.topMostViewController())
    }
}

extension FavRowCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let d = data?[indexPath.row] else { return UICollectionViewCell() }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: FeedCollectionViewCell.self), for: indexPath) as! FeedCollectionViewCell
        cell.setup(data: d)
        return cell
    }
}

