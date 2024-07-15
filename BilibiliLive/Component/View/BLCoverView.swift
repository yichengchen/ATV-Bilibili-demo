//
//  BLCoverView.swift
//  BilibiliLive
//
//  Created by Iven on 2023/9/22.
//

import UIKit

class BLCoverView: UIView {
    @IBOutlet var contentView: UIView!

    @IBOutlet var coverImageView: UIImageView! {
        didSet {
            coverImageView.setCornerRadius(cornerRadius: 40)
        }
    }

    @IBOutlet var headImage: UIImageView! {
        didSet {
            headImage.setCornerRadius(cornerRadius: headImage.height / 2)
        }
    }

    @IBOutlet var nameBgButton: UIView! {
        didSet {
//            nameBgButton.setCornerRadius(cornerRadius: 12)
//            nameBgButton.setBlurEffectView()
        }
    }

    @IBOutlet var nameLabel: UILabel!

    @IBOutlet var titleLabel: UILabel!

    @IBOutlet var timeLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView = bindNibView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindNibView(_ nibname: String? = nil) -> UIView {
        let loadName = nibname == nil ? "\(Self.self)" : nibname!
        let view = (Bundle.main.loadNibNamed(loadName, owner: self, options: nil)?.last as! UIView)
        // 添加上去
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return view
    }
}
