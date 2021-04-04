//
//  PlayerControlView.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/4.
//

protocol PlayerControlViewDelegate: class {
    func didSeek(to time: TimeInterval)
}

class PlayerControlView: UIView {
    var duration: TimeInterval = 3600
    var current: TimeInterval = 0 {
        didSet {
            updateProgress()
            updateTimeLabel()
        }
    }
    weak var delegate: PlayerControlViewDelegate?
    
    private let progressBackgoundView = UIView()
    private let indicatorView = UIView()
    private let adjustIndecatorView = UIView()
    private let currentTimeLabel = UILabel()
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
    
    override var isHidden: Bool {
        didSet {
            if isHidden {
                resignFirstResponder()
            } else {
                becomeFirstResponder()
            }
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.first?.type == .select {
            actionTap()
        }
    }
    
    override func didMoveToWindow() {
        becomeFirstResponder()
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    private func setup() {
        isUserInteractionEnabled = true
        setupView()
        setupGesture()
    }
    
    private func setupView() {
        addSubview(progressBackgoundView)
        progressBackgoundView.backgroundColor = UIColor.lightGray
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
             $0.widthAnchor.constraint(equalToConstant: 1),
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
        currentTimeLabel.text = "0:00"
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
    }
    
    
    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer()
        panGesture.delegate = self
        panGesture.allowedTouchTypes = [UITouch.TouchType.direct,UITouch.TouchType.indirect].map({NSNumber(value: $0.rawValue)})
        panGesture.addTarget(self, action: #selector(actionPan(sender:)))
        addGestureRecognizer(panGesture)
    }
    
    func updateProgress() {
        let length = CGFloat(current/duration) * progressBackgoundView.bounds.width
        playbackIndicatorLeadingContstraint!.constant = length
        if !adjusting {
            adjustIndicatorLeadingContstraint?.constant = length
        }
    }
    
    func updateTimeLabel() {
        let progress:CGFloat
        if adjusting {
            progress = adjustIndicatorLeadingContstraint!.constant/progressBackgoundView.bounds.width
        } else {
            progress = playbackIndicatorLeadingContstraint!.constant/progressBackgoundView.bounds.width
        }
        let seconds = CGFloat(duration) * progress
        currentTimeLabel.text = "\(Int(seconds / 60)):\(Int(seconds.truncatingRemainder(dividingBy: 60)))"
    }
    
    @objc func actionPan(sender:UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            adjusting = true
            sender.setTranslation(CGPoint(x: adjustIndicatorLeadingContstraint!.constant, y: 0), in: progressBackgoundView)
        case .changed:
            let move = sender.translation(in: progressBackgoundView).x
            if move < 0 || move > progressBackgoundView.bounds.width { return }
            adjustIndicatorLeadingContstraint?.constant = move
            updateTimeLabel()
        case .ended,.cancelled:
            break
        default:
            break
        }
    }
    
    @objc func actionTap() {
        if adjusting {
            let seek = CGFloat(duration) * adjustIndicatorLeadingContstraint!.constant/progressBackgoundView.bounds.width
            delegate?.didSeek(to: TimeInterval(seek))
            adjusting = false
        } else {
            delegate?.didSeek(to: current)
        }
    }
}

extension PlayerControlView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
