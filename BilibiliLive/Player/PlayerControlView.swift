//
//  PlayerControlView.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

protocol PlayerControlViewDelegate: class {
    func didSeek(to time: TimeInterval)
    var player: VLCMediaPlayer { get }
}

class PlayerControlView: UIView {
    var duration: TimeInterval = 3600 {
        didSet {
            totoalTimeLabel.text = "\(Int(duration / 60)):\(Int(duration.truncatingRemainder(dividingBy: 60)))"
        }
    }
    var current: TimeInterval = 0 {
        didSet {
            updateProgress()
            updateTimeLabel()
        }
    }
    weak var delegate: PlayerControlViewDelegate?
    
    private var timer:Timer?
    private let progressBackgoundView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let indicatorView = UIView()
    private let adjustIndecatorView = UIView()
    private let currentTimeLabel = UILabel()
    private let totoalTimeLabel = UILabel()
    private var playbackIndicatorLeadingContstraint: NSLayoutConstraint?
    private var adjustIndicatorLeadingContstraint: NSLayoutConstraint?
    private var adjustIndicatorLabelContstraint: NSLayoutConstraint?
    private var adjusting = false {
        didSet {
            adjustIndecatorView.isHidden = !adjusting
            adjustIndicatorLabelContstraint?.isActive = adjusting
        }
    }
    
    private let pressGesture = UILongPressGestureRecognizer()
    
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    
    override open class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    override func didMoveToWindow() {
        startHideTimer()
    }
    
    private func setup() {
        isUserInteractionEnabled = true
        setupView()
    }
    
    private func setupView() {
        (layer as? CAGradientLayer)?.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.8).cgColor]
        addSubview(progressBackgoundView)
        progressBackgoundView.layer.cornerRadius = 5
        progressBackgoundView.clipsToBounds = true
        progressBackgoundView.makeConstraints {
            [$0.bottomAnchor.constraint(equalTo: bottomAnchor,constant: -90),
             $0.leadingAnchor.constraint(equalTo: leadingAnchor,constant: 90),
             $0.trailingAnchor.constraint(equalTo: trailingAnchor,constant: -90),
             $0.heightAnchor.constraint(equalToConstant: 10)]
        }
        
        addSubview(indicatorView)
        indicatorView.backgroundColor = UIColor.white
        playbackIndicatorLeadingContstraint = indicatorView.leadingAnchor.constraint(equalTo: progressBackgoundView.leadingAnchor)
        indicatorView.makeConstraints {
            [$0.heightAnchor.constraint(equalTo: progressBackgoundView.heightAnchor),
             $0.widthAnchor.constraint(equalToConstant: 2),
             $0.bottomAnchor.constraint(equalTo: progressBackgoundView.bottomAnchor),
             playbackIndicatorLeadingContstraint!]
        }
        
        addSubview(adjustIndecatorView)
        adjustIndecatorView.backgroundColor = UIColor.white
        adjustIndicatorLeadingContstraint = adjustIndecatorView.leadingAnchor.constraint(equalTo: progressBackgoundView.leadingAnchor)
        adjustIndecatorView.isHidden = true
        adjustIndecatorView.makeConstraints {
            [$0.heightAnchor.constraint(equalToConstant: 30),
             $0.widthAnchor.constraint(equalToConstant: 2),
             $0.bottomAnchor.constraint(equalTo: progressBackgoundView.bottomAnchor),
             adjustIndicatorLeadingContstraint!]
        }
        
        addSubview(currentTimeLabel)
        currentTimeLabel.text = "0:0"
        currentTimeLabel.textColor = UIColor.white
        currentTimeLabel.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        
        let currentTimeCenterXConstarint = currentTimeLabel.centerXAnchor.constraint(equalTo: indicatorView.centerXAnchor)
        currentTimeCenterXConstarint.priority = .dragThatCanResizeScene
        adjustIndicatorLabelContstraint = currentTimeLabel.centerXAnchor.constraint(equalTo: adjustIndecatorView.centerXAnchor)
        adjustIndicatorLabelContstraint?.priority = .defaultHigh
        currentTimeLabel.makeConstraints {
            [$0.leadingAnchor.constraint(greaterThanOrEqualTo: progressBackgoundView.leadingAnchor,constant: 0),
             $0.topAnchor.constraint(equalTo: progressBackgoundView.bottomAnchor,constant: 10),
             currentTimeCenterXConstarint]
        }
        
        addSubview(totoalTimeLabel)
        totoalTimeLabel.textColor = UIColor.white
        totoalTimeLabel.font = UIFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        totoalTimeLabel.makeConstraints {
            [$0.topAnchor.constraint(equalTo: progressBackgoundView.bottomAnchor,constant: 10),
             $0.trailingAnchor.constraint(equalTo: progressBackgoundView.trailingAnchor)]
        }
    }
    
    
    func setupGesture(with target:UIView) {
        let panGesture = UIPanGestureRecognizer()
        panGesture.allowedTouchTypes = [UITouch.TouchType.direct,UITouch.TouchType.indirect].map({NSNumber(value: $0.rawValue)})
        panGesture.addTarget(self, action: #selector(actionPan(sender:)))
        panGesture.delegate = self
        target.addGestureRecognizer(panGesture)
    }
    
    private func updateProgress() {
        let length = CGFloat(current/duration) * progressBackgoundView.bounds.width
        playbackIndicatorLeadingContstraint!.constant = length
        if !adjusting {
            adjustIndicatorLeadingContstraint?.constant = length
        }
    }
    
    private func updateTimeLabel() {
        let progress:CGFloat
        if adjusting {
            progress = adjustIndicatorLeadingContstraint!.constant/progressBackgoundView.bounds.width
        } else {
            progress = playbackIndicatorLeadingContstraint!.constant/progressBackgoundView.bounds.width
        }
        let seconds = CGFloat(duration) * progress
        currentTimeLabel.text = "\(Int(seconds / 60)):\(Int(seconds.truncatingRemainder(dividingBy: 60)))"
    }
    
    private func startHideTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: {
            [weak self] _ in
            guard let self = self else { return }
            self.hide()
        })
    }
    
    func hide() {
        adjusting = false
        if isHidden { return }
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { _ in
            self.isHidden = true
        }
    }
    
    func show() {
        if !isHidden {
            startHideTimer()
            return
        }
        alpha = 0
        isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
        startHideTimer()
    }
    
    @objc func actionPan(sender:UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            if isHidden {
                show()
            }
            adjusting = true
            timer?.invalidate()
            sender.setTranslation(CGPoint(x: adjustIndicatorLeadingContstraint!.constant, y: 0), in: progressBackgoundView)
        case .changed:
            let move = sender.translation(in: progressBackgoundView).x
            if move < 0 || move > progressBackgoundView.bounds.width { return }
            adjustIndicatorLeadingContstraint?.constant = move
            updateTimeLabel()
        case .ended,.cancelled:
            startHideTimer()
        default:
            break
        }
    }
    
    @objc func actionTap() {
        if isHidden {
            show()
            return
        }
        if adjusting {
            let seek = CGFloat(duration) * adjustIndicatorLeadingContstraint!.constant/progressBackgoundView.bounds.width
            delegate?.didSeek(to: TimeInterval(seek))
            adjusting = false
        } else {
            delegate?.player.play()
        }
        startHideTimer()
    }
}

extension PlayerControlView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UISwipeGestureRecognizer {
            return delegate?.player.isPlaying ?? false
        }
        return false
    }
}
