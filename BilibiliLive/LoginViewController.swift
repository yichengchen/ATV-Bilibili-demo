//
//  LoginViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import Alamofire
import Foundation
import SwiftyJSON
import UIKit

class LoginViewController: UIViewController {
    @IBOutlet var qrcodeImageView: UIImageView!
    var currentLevel: Int = 0, finalLevel: Int = 200
    var timer: Timer?
    var oauthKey: String = ""

    static func create() -> LoginViewController {
        let loginVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "Login") as! LoginViewController
        return loginVC
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
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
