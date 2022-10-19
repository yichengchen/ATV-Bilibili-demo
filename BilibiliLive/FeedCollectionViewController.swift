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

extension FeedDisplayStyle {
    var cellSize: CGSize {
        switch self {
        case .large:
            return CGSize(width: 570, height: 450)
        case .normal:
            return CGSize(width: 440, height: 370)
        }
    }
    
    var spacing: CGFloat {
        switch self {
        case .large:
            return 30
        case .normal:
            return 10
        }
    }
    
    var lineSpacing: CGFloat {
        switch self {
        case .large:
            return 20
        case .normal:
            return 2
        }
    }
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
        let style = Settings.displayStyle
        layout.headerReferenceSize = .zero
        layout.itemSize = style.cellSize
        layout.minimumLineSpacing = style.lineSpacing
        layout.minimumInteritemSpacing = style.spacing
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
    
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let previousIndexPath = context.previouslyFocusedIndexPath,
           let cell = collectionView.cellForItem(at:previousIndexPath) as? HomeCollectionViewCell {
            cell.stopScroll()
        }
        if let previousIndexPath = context.nextFocusedIndexPath,
           let cell = collectionView.cellForItem(at:previousIndexPath) as? HomeCollectionViewCell {
            cell.startScroll()
        }
        
    }
    
    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        let indexPath = IndexPath(item: 0, section: 0)
        return indexPath
    }
    
}





class HomeCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: MarqueeLabel!
    @IBOutlet weak var upLabel: MarqueeLabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint?
    
    
    var onLongPress: (()->Void)?=nil
    override func awakeFromNib() {
        super.awakeFromNib()
        let longpress = UILongPressGestureRecognizer(target: self, action: #selector(actionLongPress(sender:)))
        addGestureRecognizer(longpress)
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        
        if Settings.displayStyle == .normal {
            imageViewHeightConstraint?.constant = 250
            titleLabel.font = UIFont.systemFont(ofSize: 30,weight: .semibold)
            upLabel.font = UIFont.systemFont(ofSize: 20)
        }
    }
    
    func setup(data: DisplayData) {
        titleLabel.text = data.title
        upLabel.text = data.owner
        imageView.kf.setImage(with:data.pic)
        
    }
    
    func startScroll() {
        titleLabel.restartLabel()
        upLabel.restartLabel()
    }
    
    func stopScroll() {
        titleLabel.shutdownLabel()
        upLabel.shutdownLabel()
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
