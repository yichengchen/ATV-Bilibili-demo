//
//  LoginViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/3/28.
//

import UIKit
import Alamofire
import SwiftyJSON
import Foundation

class LoginViewController: UIViewController {
    
    @IBOutlet weak var qrcodeImageView: UIImageView!
    var currentLevel:Int = 0, finalLevel:Int = 200
    var timer: Timer?
    var oauthKey: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
    
    func initValidation() -> Void {
        timer?.invalidate()
        AF.request("https://passport.bilibili.com/qrcode/getLoginUrl").responseJSON {
            [weak self] response in
            guard let self = self else {return}
            switch(response.result) {
            case .success(let data):
                let json = JSON(data)
                guard let url = json["data"]["url"].string,
                      let oauthKey = json["data"]["oauthKey"].string else {
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                
                self.qrcodeImageView.image = self.generateQRCode(from: url)
                self.oauthKey = oauthKey
                self.startValidationTimer()
            case .failure(_):
                print("------loopValidation---------")
                break
            }
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
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func loopValidation() -> Void{
        let params:Parameters = [
            "oauthKey": oauthKey,
            "gourl": "http://www.bilibili.com"
        ]
        AF.request("https://passport.bilibili.com/qrcode/getLoginInfo",
                   method: .post,
                   parameters: params)
            .responseJSON {
                [weak self] response in
                guard let self = self else { return }
                switch(response.result) {
                case .success(let data):
                    let json = JSON(data)
                    let status = json["status"].boolValue
                    if status {
                        CookieHandler.shared.backupCookies()
                        self.stopValidationTimer()
                        self.didValidationSuccess()
                        return
                    }
                    
                    let data = json["data"].intValue
                    print("data:",data)
                    // -1：密钥错误 -2：密钥超时  -4：未扫描 -5：未确认
                    if data == -2 {
                        self.initValidation()
                    }
                case .failure( _):
                    print("------loopValidation---------")
                    break
                }
            }
    }
    
    @IBAction func actionStart(_ sender: Any) {
        initValidation()
    }
}

