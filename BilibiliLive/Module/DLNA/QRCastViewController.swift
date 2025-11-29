//
//  QRCastViewController.swift
//  BilibiliLive
//
//  Created for QR code based screen casting
//

import UIKit

class QRCastViewController: UIViewController {
    private let qrCodeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "扫码投屏"
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "使用哔哩哔哩手机客户端扫描二维码\n即可将视频投屏到本设备"
        label.font = .systemFont(ofSize: 28)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        return label
    }()

    private let deviceInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .tertiaryLabel
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.textAlignment = .center
        label.textColor = .systemGreen
        return label
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("关闭", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28)
        return button
    }()

    private var refreshTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        generateQRCode()
        startStatusMonitoring()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func setupUI() {
        // tvOS doesn't have systemBackground, use clear or a dark color
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)

        view.addSubview(titleLabel)
        view.addSubview(qrCodeImageView)
        view.addSubview(instructionLabel)
        view.addSubview(deviceInfoLabel)
        view.addSubview(statusLabel)
        view.addSubview(closeButton)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(60)
            make.centerX.equalToSuperview()
        }

        qrCodeImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(400)
        }

        instructionLabel.snp.makeConstraints { make in
            make.top.equalTo(qrCodeImageView.snp.bottom).offset(40)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }

        deviceInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(instructionLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }

        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(deviceInfoLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
            make.centerX.equalToSuperview()
        }

        closeButton.addTarget(self, action: #selector(closeTapped), for: .primaryActionTriggered)
    }

    private func generateQRCode() {
        // Get device info from DLNA service
        let dmr = BiliBiliUpnpDMR.shared

        guard let ip = dmr.getDeviceIP() else {
            showError("无法获取设备IP地址，请确保已连接网络")
            return
        }

        let uuid = dmr.getDeviceUUID()
        let port: UInt16 = 9958

        // Generate QR code content
        // Format: bilibili://tv_cast?ip=xxx&port=xxx&uuid=xxx&name=xxx
        // This format is designed to be compatible with Bilibili's potential QR casting feature
        let deviceName = "我的小电视"
        let qrContent = "http://\(ip):\(port)/dlna/device.xml?uuid=\(uuid)&name=\(deviceName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceName)"

        Logger.info("[QRCast] Generating QR code with content: \(qrContent)")

        if let qrImage = generateQRCodeImage(from: qrContent) {
            qrCodeImageView.image = qrImage
        } else {
            showError("生成二维码失败")
        }

        // Update device info label
        deviceInfoLabel.text = "设备名称: \(deviceName)\nIP: \(ip):\(port)\nUUID: \(uuid.prefix(12))..."

        updateStatus()
    }

    private func generateQRCodeImage(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

            if let outputImage = filter.outputImage {
                // Scale up the QR code for better visibility
                let scaleX = 400 / outputImage.extent.size.width
                let scaleY = 400 / outputImage.extent.size.height
                let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                // Convert to UIImage with proper rendering
                let context = CIContext()
                if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }

    private func startStatusMonitoring() {
        // Monitor for incoming connections
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func updateStatus() {
        let dmr = BiliBiliUpnpDMR.shared

        if dmr.isStarted() {
            statusLabel.text = "投屏服务已启动，等待连接..."
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = "投屏服务未启动"
            statusLabel.textColor = .systemRed
        }
    }

    private func showError(_ message: String) {
        instructionLabel.text = message
        instructionLabel.textColor = .systemRed
        qrCodeImageView.image = nil
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - BiliBiliUpnpDMR Extension for QR Cast

extension BiliBiliUpnpDMR {
    /// Get device IP address for QR code
    func getDeviceIP() -> String? {
        return getNetworkInterface()?.ip
    }

    /// Get device UUID for QR code
    func getDeviceUUID() -> String {
        return Settings.uuid
    }

    /// Check if DLNA service is running
    func isStarted() -> Bool {
        return started
    }
}
