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
    var qrcodeImageView: UIImageView!
    var currentLevel: Int = 0, finalLevel: Int = 200
    var timer: Timer?
    var oauthKey: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        BLTabBarViewController.clearSelected()
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

    func setup() {
        let leftContainerView = UIView()
        view.addSubview(leftContainerView)
        leftContainerView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.5)
        }

        let separator = UIView()
        separator.backgroundColor = .darkGray
        view.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.width.equalTo(2)
            make.top.bottom.centerX.equalToSuperview()
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 50
        leftContainerView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        qrcodeImageView = UIImageView()
        stack.addArrangedSubview(qrcodeImageView)
        qrcodeImageView.snp.makeConstraints { make in
            #if PLATFORM_TVOS
                make.width.height.equalTo(540)
            #else
                make.width.height.equalTo(300)
            #endif
        }

        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("重新生成二维码", for: .normal)
        refreshButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(refreshButton)
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)

            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        return nil
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
        let alert = UIAlertController()
        alert.addAction(UIAlertAction(title: "Success", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
            AppDelegate.shared.showTabBar()
        }))
        present(alert, animated: true, completion: nil)
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
            case let .success(token):
                print(token)
                UserDefaults.standard.set(codable: token, forKey: "token")
                self.didValidationSuccess()
            case .fail:
                break
            }
        }
    }

    @IBAction func actionStart(_ sender: Any) {
        initValidation()
    }
}
