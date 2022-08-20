//
//  PersonalMasterViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/8/20.
//

import UIKit


struct CellModel {
    let title:String
    let action: (()->Void)?
}

class PersonalViewController: UIViewController {
    static func create() -> PersonalViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "My") as! PersonalViewController
    }

    @IBOutlet weak var contentView: UIView!
    var currentViewController: UIViewController?
    
    var cellModels = [CellModel]()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        cellModels.first?.action?()
    }
    
    
    func setupData() {
        let setting = CellModel(title: "设置") {
            [weak self] in
            self?.setViewController(vc: EmptyViewController())
        }
        cellModels.append(setting)
        let logout = CellModel(title: "登出") {
            [weak self] in
            self?.actionLogout()
        }
        cellModels.append(logout)
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
    
    func actionLogout() {
        let alert = UIAlertController(title: "确定登出？", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default){
            _ in
            ApiRequest.logout() {
                WebRequest.logout() {
                    AppDelegate.shared.showLogin()
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

extension PersonalViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        label.text = cellModels[indexPath.item].title
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cellModels.count
    }
}

extension PersonalViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        cellModels[indexPath.item].action?()
    }
}


class EmptyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "Nothing Here"
        view.addSubview(label)
        label.makeConstraintsBindToCenterOfSuperview()
    }
}
