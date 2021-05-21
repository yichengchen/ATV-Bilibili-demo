//
//  CommonPlayerViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

import UIKit
import TVVLCKit

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
    let menuRecognizer = UITapGestureRecognizer()
    let leftPressRecognizer = UILongPressGestureRecognizer()
    let rightPressRecognizer = UILongPressGestureRecognizer()

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
        
        menuRecognizer.addTarget(self, action: #selector(actionMenu))
        menuRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuRecognizer)

        leftPressRecognizer.addTarget(self, action: #selector(actionLongLeft(sender:)))
        leftPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        leftPressRecognizer.minimumPressDuration = 1
        view.addGestureRecognizer(leftPressRecognizer)
        
        rightPressRecognizer.addTarget(self, action: #selector(actionLongRight(sender:)))
        rightPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        rightPressRecognizer.minimumPressDuration = 1
        view.addGestureRecognizer(rightPressRecognizer)
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let pressType = presses.first?.type else { return }
        switch pressType {
        case .select:
            controlView.show()
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
        player.jumpForward(10)
        controlView.show()
    }
    
    @objc func backward() {
        guard player.isSeekable, player.time.value != nil else { return }
        player.jumpBackward(10)
        controlView.show()
    }
    
    @objc func actionMenu() {
        if !controlView.isHidden {
            controlView.hide()
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func actionLongLeft(sender: UILongPressGestureRecognizer) {
        controlView.show()
        switch sender.state {
        case .began:
            controlView.timer?.invalidate()
            player.rewind(atRate: 20)
        case .ended,.cancelled:
            player.rewind(atRate: 0)
        default:
            break
        }
    }
    
    @objc func actionLongRight(sender: UILongPressGestureRecognizer) {
        controlView.show()
        switch sender.state {
        case .began:
            controlView.timer?.invalidate()
            player.fastForward(atRate: 20)
        case .ended,.cancelled:
            player.fastForward(atRate: 1)
        default:
            break
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
        loading?.stopAnimating()
        loading?.removeFromSuperview()
        loading = nil
    }
}

extension CommonPlayerViewController: PlayerControlViewDelegate {
    func didSeek(to time: TimeInterval) {
        player.play()
        player.time = VLCTime(int: Int32(Int(time)) * 1000)
        didSeek?(time)
    }
}
