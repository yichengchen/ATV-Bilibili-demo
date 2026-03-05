//
//  LoginViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Alamofire
import Foundation
import SnapKit
import SwiftyJSON
import UIKit

class LoginViewController: UIViewController {
    private let ciContext = CIContext()

    private let qrcodeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let regenerateButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "重新生成二维码"
        config.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let leftContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.3333333333, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "账号登录"
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let guideLabel: UILabel = {
        let label = UILabel()
        label.text = "1 请打开BiliBili官方手机客户端扫码登录\n\n2. 如果登录失败尝试点击重新生成二维码"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var currentLevel: Int = 0, finalLevel: Int = 200
    var timer: Timer?
    var oauthKey: String = ""

    static func create() -> LoginViewController {
        LoginViewController()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initValidation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        qrcodeImageView.image = nil
        stopValidationTimer()
    }

    func generateQRCode(from string: String) -> UIImage? {
        guard
            let data = string.data(using: .ascii),
            let filter = CIFilter(name: "CIQRCodeGenerator")
        else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let extent = outputImage.extent.integral
        guard !extent.isEmpty else { return nil }

        let targetSize: CGFloat = 540
        let scale = max(1, floor(targetSize / max(extent.width, extent.height)))
        let width = Int(extent.width * scale)
        let height = Int(extent.height * scale)

        guard
            let cgImage = ciContext.createCGImage(outputImage, from: extent),
            let bitmapContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            return nil
        }

        bitmapContext.interpolationQuality = .none
        bitmapContext.scaleBy(x: scale, y: scale)
        bitmapContext.draw(cgImage, in: extent)

        guard let scaledImage = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: scaledImage)
    }

    func initValidation() {
        timer?.invalidate()
        ApiRequest.requestLoginQR { [weak self] code, url in
            guard let self else { return }
            let image = self.generateQRCode(from: url)
            self.qrcodeImageView.image = image
            self.oauthKey = code
            self.startValidationTimer()
        }
    }

    func startValidationTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentLevel += 1
            if self.currentLevel > self.finalLevel {
                self.stopValidationTimer()
            }
            self.loopValidation()
        }
    }

    func stopValidationTimer() {
        timer?.invalidate()
        timer = nil
    }

    func didValidationSuccess() {
        qrcodeImageView.image = nil
        AppDelegate.shared.showTabBar()
        stopValidationTimer()
    }

    func loopValidation() {
        ApiRequest.verifyLoginQR(code: oauthKey) {
            [weak self] state in
            guard let self = self else { return }
            switch state {
            case .expire:
                self.initValidation()
            case .waiting:
                break
            case let .success(token, cookies):
                print(token)
                AccountManager.shared.registerAccount(token: token, cookies: cookies) { [weak self] _ in
                    self?.didValidationSuccess()
                }
            case .fail:
                break
            }
        }
    }

    @objc private func actionStart() {
        initValidation()
    }

    private func setupUI() {
        view.backgroundColor = .black

        view.addSubview(leftContainerView)
        view.addSubview(dividerView)
        view.addSubview(titleLabel)
        view.addSubview(guideLabel)

        let qrStackView = UIStackView(arrangedSubviews: [qrcodeImageView, regenerateButton])
        qrStackView.axis = .vertical
        qrStackView.alignment = .center
        qrStackView.spacing = 50
        qrStackView.translatesAutoresizingMaskIntoConstraints = false
        leftContainerView.addSubview(qrStackView)

        regenerateButton.addTarget(self, action: #selector(actionStart), for: .primaryActionTriggered)

        leftContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5)
        }

        qrStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        qrcodeImageView.snp.makeConstraints { make in
            make.width.height.equalTo(540)
        }

        dividerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalTo(view.safeAreaLayoutGuide)
            make.width.equalTo(2)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(dividerView.snp.trailing).offset(100)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(120)
        }

        guideLabel.snp.makeConstraints { make in
            make.leading.equalTo(dividerView.snp.trailing).offset(100)
            make.top.equalTo(titleLabel.snp.bottom).offset(50)
            make.trailing.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.trailing).offset(-100)
        }
    }
}
