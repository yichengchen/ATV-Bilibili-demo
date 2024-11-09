//
// Created by Yam on 2024/6/9.
//

import Kingfisher
import UIKit

class ReplyDetailViewController: UIViewController {
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var titleLabel: UILabel!
    private var replyLabel: UIButton!
    private var replyCollectionView: UICollectionView!
    private var imageStackView: UIStackView!

    private let reply: Replys.Reply

    init(reply: Replys.Reply) {
        self.reply = reply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpViews()
        replyLabel.setTitle(reply.content.message, for: .normal)
        reply.content.pictures?.compactMap { URL(string: $0.img_src) }.forEach { url in
            let imageView = UIImageView()
            imageView.kf.setImage(with: url)
            imageView.contentMode = .scaleAspectFit
            imageView.snp.makeConstraints { make in
                make.height.lessThanOrEqualTo(500)
            }
            imageStackView.addArrangedSubview(imageView)
        }
    }

    // MARK: - Private

    private func setUpViews() {
        scrollView = {
            let scroll = UIScrollView()
            view.addSubview(scroll)
            scroll.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            return scroll
        }()

        contentView = {
            let view = UIView()
            scrollView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.width.equalToSuperview()
            }
            return view
        }()

        titleLabel = {
            let label = UILabel()
            contentView.addSubview(label)
            label.font = .boldSystemFont(ofSize: 60)
            label.text = "评论"

            label.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(20)
            }

            return label
        }()

        replyLabel = {
            let label = UIButton()
            contentView.addSubview(label)
            label.titleLabel?.numberOfLines = 0
            label.titleLabel?.textAlignment = .left
            label.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            label.contentHorizontalAlignment = .left
            label.snp.makeConstraints { make in
                make.top.equalTo(self.titleLabel.snp.bottom).offset(60)
                make.leading.equalTo(contentView.snp.leadingMargin)
                make.trailing.equalTo(contentView.snp.trailingMargin)
            }

            return label
        }()

        imageStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 10
            contentView.addSubview(stackView) // 改为添加到 contentView

            stackView.snp.makeConstraints { make in
                make.top.equalTo(self.replyLabel.snp.bottom).offset(60)
                make.leading.equalTo(contentView.snp.leadingMargin)
                make.trailing.equalTo(contentView.snp.trailingMargin)
            }
            return stackView
        }()

        replyCollectionView = {
            let flowLayout = UICollectionViewFlowLayout()
            flowLayout.itemSize = CGSize(width: 582, height: 360)
            flowLayout.sectionInset = .init(top: 0, left: 60, bottom: 0, right: 60)
            flowLayout.minimumLineSpacing = 10
            flowLayout.minimumInteritemSpacing = 10

            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
            contentView.addSubview(collectionView)
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.register(UINib(nibName: ReplyCell.identifier, bundle: nil), forCellWithReuseIdentifier: ReplyCell.identifier)

            collectionView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(self.imageStackView.snp.bottom).offset(60)
                make.height.width.equalTo(360)
                make.bottom.equalToSuperview()
            }

            return collectionView
        }()
    }
}

extension ReplyDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return reply.replies?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReplyCell.identifier, for: indexPath) as? ReplyCell else {
            fatalError("cell not found")
        }

        guard let reply = reply.replies?[indexPath.row] else {
            fatalError("reply not found")
        }

        cell.config(replay: reply)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let reply = reply.replies?[indexPath.item] else { return }
        let detail = ReplyDetailViewController(reply: reply)
        present(detail, animated: true)
    }
}
