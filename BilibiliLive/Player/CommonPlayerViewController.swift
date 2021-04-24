//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit

class CommonPlayerViewController: UIViewController {
    let player = VLCMediaPlayer()
    let playerView = UIView()
    let controlView = PlayerControlView()
    var loading: UIActivityIndicatorView?
    var playerTimeChanged: ((TimeInterval) -> Void)?=nil
    var didSeek: ((TimeInterval)->Void)?=nil
    var didPause:(()->Void)?=nil
    var didPlay: (()->Void)?=nil
    var didEnd: (()->Void)?=nil
    let rightSwipGesture = UISwipeGestureRecognizer()
    let leftSwipGesture = UISwipeGestureRecognizer()
    let leftPressRecognizer = UILongPressGestureRecognizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        view.addSubview(playerView)
        playerView.makeConstraintsToBindToSuperview()
        player.drawable = playerView
        player.delegate = self
        
        controlView.delegate = self
        view.addSubview(controlView)
        controlView.makeConstraints {
            [$0.leadingAnchor.constraint(equalTo: view.leadingAnchor),
             $0.trailingAnchor.constraint(equalTo: view.trailingAnchor),
             $0.bottomAnchor.constraint(equalTo: view.bottomAnchor),
             $0.heightAnchor.constraint(equalToConstant: 200)]
        }
        controlView.setupGesture(with: view)
        
        loading = UIActivityIndicatorView()
        loading?.style = .large
        loading?.color = UIColor.white
        view.addSubview(loading!)
        loading?.startAnimating()
        loading?.makeConstraints {
            [$0.centerYAnchor.constraint(equalTo: view.centerYAnchor),
             $0.centerXAnchor.constraint(equalTo: view.centerXAnchor)]
        }
        
        rightSwipGesture.direction = .right
        rightSwipGesture.addTarget(self, action: #selector(forward))
        view.addGestureRecognizer(rightSwipGesture)
        
        leftSwipGesture.direction = .left
        leftSwipGesture.addTarget(self, action: #selector(backward))
        view.addGestureRecognizer(leftSwipGesture)
        
        leftPressRecognizer.addTarget(self, action: #selector(actionMenu))
        leftPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        leftPressRecognizer.minimumPressDuration = 1
        view.addGestureRecognizer(leftPressRecognizer)
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let pressType = presses.first?.type else { return }
        switch pressType {
        case .select:
            if player.isPlaying {
                player.pause()
            } else {
                controlView.actionTap()
            }
        case .playPause:
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
        case .leftArrow:
            backward()
        case .rightArrow:
            forward()
        default:
            break
        }
    }
    
    @objc func forward() {
        guard player.isSeekable, player.time.value != nil else { return }
        let newTime = player.time.value.int32Value + 10 * 1000
        player.time = VLCTime(int: newTime)
        controlView.show()
    }
    
    @objc func backward() {
        guard player.isSeekable, player.time.value != nil else { return }
        let newTime = player.time.value.int32Value - 10 * 1000
        player.time = VLCTime(int: newTime)
        controlView.show()
    }
    
    @objc func actionMenu() {
        if !controlView.isHidden {
            controlView.hide()
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
}

extension CommonPlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        switch player.state {
        case .paused:
            didPause?()
        case .playing:
            didPlay?()
            fallthrough
        case .esAdded:
            loading?.stopAnimating()
            loading?.removeFromSuperview()
            loading = nil
        case .ended:
            didEnd?()
        default:
            break
        }
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        let current = TimeInterval(player.time.intValue/1000)
        controlView.duration = TimeInterval(player.media.length.intValue/1000)
        controlView.current = current
        playerTimeChanged?(current)
    }
}

extension CommonPlayerViewController: PlayerControlViewDelegate {
    func didSeek(to time: TimeInterval) {
        player.play()
        player.time = VLCTime(int: Int32(Int(time)) * 1000)
        didSeek?(time)
    }
}
