//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/5.
//

import UIKit

protocol DisplayData {
    var title: String { get }
    var owner: String { get }
    var pic: URL? { get }
}

class FeedCollectionViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    var headerTitle: String? {
        didSet {
            layout.headerReferenceSize = CGSize(width: 1080, height: 50)
        }
    }
    var didSelect: ((IndexPath)->Void)? = nil
    var didLongPress: ((IndexPath)->Void)? = nil
    lazy var layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
    var displayDatas = [DisplayData]() {
        didSet {
            collectionView.reloadData()
        }
    }
    
    static func create() -> FeedCollectionViewController {
        return UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "FeedCollectionViewController") as! FeedCollectionViewController
    }
    
    func show(in vc: UIViewController) {
        vc.addChild(self)
        vc.view.addSubview(view)
        view.makeConstraintsToBindToSuperview()
        didMove(toParent: vc)
        vc.tabBarObservedScrollView = collectionView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layout.headerReferenceSize = .zero
    }
}


extension FeedCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelect?(indexPath)
    }
}

extension FeedCollectionViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayDatas.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! HomeCollectionViewCell
        let item = displayDatas[indexPath.item]
        cell.setup(data: item)
        cell.onLongPress = {
            [weak self] in
            self?.didLongPress?(indexPath)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if let title = headerTitle {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
            let label = header.viewWithTag(1) as! UILabel
            label.text = title
            return header
        }
        return UICollectionReusableView()
    }
    
}





class HomeCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var upLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var onLongPress: (()->Void)?=nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.clipsToBounds = false
        contentView.layer.shadowOffset = CGSize(width: 10, height: 10)
        contentView.layer.shadowColor = UIColor.gray.cgColor
        contentView.layer.shadowRadius = 20
        contentView.layer.shadowOpacity = 1
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)
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
    
    func setup(data: DisplayData) {
        titleLabel.text = data.title
        upLabel.text = data.owner
        imageView.kf.setImage(with:data.pic)
    }
    
    @objc private func actionLongPress(sender:UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        onLongPress?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        onLongPress = nil
    }
}
