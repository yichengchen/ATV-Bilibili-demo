//
// Created by Yam on 2024/6/9.
//

import UIKit

class ReplyDetailViewController: UIViewController {
    private var titleLabel: UILabel!
    private var replyLabel: UILabel!
    private var replyCollectionView: UICollectionView!

    var reply: Replys.Reply

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
        replyLabel.text = reply.content.message
    }

    // MARK: - Private

    private func setUpViews() {
        titleLabel = {
            let label = UILabel()
            self.view.addSubview(label)
            label.font = .boldSystemFont(ofSize: 60)
            label.text = "评论"

            label.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(view.safeAreaLayoutGuide)
            }

            return label
        }()

        replyLabel = {
            let label = UILabel()
            self.view.addSubview(label)
            label.numberOfLines = 0
            label.font = .preferredFont(forTextStyle: .headline)

            label.snp.makeConstraints { make in
                make.top.equalTo(self.titleLabel.snp.bottom).offset(60)
                make.leading.equalTo(self.view.snp.leadingMargin)
                make.trailing.equalTo(self.view.snp.trailingMargin)
            }

            return label
        }()

        replyCollectionView = {
            let flowLayout = UICollectionViewFlowLayout()
            flowLayout.itemSize = CGSize(width: 582, height: 360)
            flowLayout.sectionInset = .init(top: 0, left: 60, bottom: 0, right: 60)
            flowLayout.minimumLineSpacing = 10
            flowLayout.minimumInteritemSpacing = 10

            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
            self.view.addSubview(collectionView)
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.register(UINib(nibName: ReplyCell.identifier, bundle: nil), forCellWithReuseIdentifier: ReplyCell.identifier)

            collectionView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalTo(self.replyLabel.snp.bottom).offset(60)
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
