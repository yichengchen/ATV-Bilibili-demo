//
//  CategoryViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2023/2/26.
//

import Foundation
import UIKit

class CategoryViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CategoryDisplayModel {
        let title: String
        let contentVC: UIViewController
    }

    var typeCollectionView: UICollectionView!
    var categories = [CategoryDisplayModel]()
    let contentView = UIView()
    weak var currentViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        typeCollectionView = UICollectionView(frame: .zero, collectionViewLayout: BLSettingLineCollectionViewCell.makeLayout())
        typeCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        view.addSubview(typeCollectionView)
        typeCollectionView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.width.equalTo(500)
        }
        typeCollectionView.dataSource = self
        typeCollectionView.delegate = self

        view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.bottom.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.equalTo(typeCollectionView.snp.right)
        }
        typeCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(typeCollectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
    }

    func setViewController(vc: UIViewController) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }
}

extension CategoryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLSettingLineCollectionViewCell
        cell.titleLabel.text = categories[indexPath.item].title
        return cell
    }
}

extension CategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setViewController(vc: categories[indexPath.item].contentVC)
    }
}
