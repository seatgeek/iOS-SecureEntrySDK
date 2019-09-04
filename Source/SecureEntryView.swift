//
//  SecureEntryView.swift
//  SecureEntryView
//
//  Created by Karl White on 11/30/18.
//  Copyright © 2019 Ticketmaster. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit

@IBDesignable
public class SecureEntryView: UIView {
  
  // MARK: Public variables

  /**
   Allows the pdf417's animation and subtitle to be colored.
   
   The default value for this property is a *blue* color (set through the *blue* class property of UIColor)
  */
  @IBInspectable
  public var brandingColor: UIColor = .blue {
    didSet {
      scanAnimationView.tintColor = brandingColor
      if isSubtitleBrandingEnabled { barcodeView.label.textColor = brandingColor }
    }
  }
  
  /**
   Subtitle for the QR variant of the SafeTix ticket.
   
   The default value for this property is *"Screenshots are not accepted for entry"*.
   
   - Note:
   Set an *empty* string to hide subtitle.
   */
  @IBInspectable
  public var qrSubtitle: String = "Screenshots are not accepted for entry" {
    didSet {
      state = state.setQRCodeSubtitle(qrSubtitle)
    }
  }
  
  /**
   Subtitle for the PDF417 variant of the SafeTix ticket.
   
   The default value for this property is *"Screenshots are not accepted for entry"*.
   
   - Note:
    Set an *empty* string to hide subtitle.
   */
  @IBInspectable
  public var pdf417Subtitle: String = "Screenshots are not accepted for entry" {
    didSet {
      state = state.setPDF417Subtitle(pdf417Subtitle)
    }
  }
  
  /**
   Set true to use *brandingColor* instead of *#262626* for subtitles.
   
   The default value for this property is *false*.
   */
  @IBInspectable
  public var isSubtitleBrandingEnabled: Bool = false {
    didSet {
      barcodeView.label.textColor = isSubtitleBrandingEnabled ? brandingColor : .mineShaft
    }
  }
  
  /**
   Error message to display in case of ivalid token
   
   The default value for this property is *"Reload ticket"*.
   */
  @IBInspectable
  public var errorMessage: String = "Reload ticket" {
    didSet {
      state = state.setErrorMessage(errorMessage)
    }
  }
  
  /**
   Token to generate the barcode.
   
   The default value for this property is *nil*.
   */
  public var token: String? {
    didSet {
      guard token != oldValue else { return }
      guard let token = token else {
        entryData = nil
        return
      }
      
      entryData = EntryData(from: token)
    }
  }

  // MARK: Internal variables

  var entryData: EntryData? {
    didSet {
      state = state.reset()
      update()
      UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
  }

  var state: State = .none {
    didSet {
      state.update(self)
      
      switch state {
      case .rotatingPDF417(_, _, _, _, _, let toggle):
        
        if toggle {
          if toggleTimer == nil {
            toggleTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) {
              [weak self] (_) in
              guard let this = self else { return }
              this.toggle(this)
            }
          }
        }
        else {
          toggleTimer?.invalidate()
          toggleTimer = nil
        }
        
        if case .rotatingPDF417 = oldValue { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] (_) in
          self?.update()
        }
        timer?.tolerance = 0.25
        
      default:
        toggleTimer?.invalidate()
        toggleTimer = nil
        
        timer?.invalidate()
        timer = nil
      }
    }
  }

  var timer: Timer?
  
  var toggleTimer: Timer?
  
  var loadingImage: UIImage?
  
  // MARK: Subviews
  
  lazy var barcodeView: SubtitledView = {
    let subtitledView = SubtitledView()
    subtitledView.translatesAutoresizingMaskIntoConstraints = false
    return subtitledView
  }()
  
  lazy var toggleButton: UIButton = {
    let button = UIButton()
    button.isAccessibilityElement = false
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(toggle(_:)), for: .touchUpInside)
    return button
  }()
  
  lazy var errorView: ErrorView = {
    let errorView = ErrorView()
    errorView.translatesAutoresizingMaskIntoConstraints = false
    return errorView
  }()
  
  lazy var scanAnimationView: ScanAnimationView = {
    let scanAnimationView = ScanAnimationView()
    scanAnimationView.translatesAutoresizingMaskIntoConstraints = false
    return scanAnimationView
  }()
  
  // MARK: Overriten Variables
  
  public override var intrinsicContentSize: CGSize {
    return CGSize(width: 220.0, height: 160.0)
  }
  
  // MARK: Initialization
  
  override public init(frame: CGRect) {
		super.init(frame: frame)
		self.setupView()
	}
  
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
  
  deinit {
    timer?.invalidate()
    toggleTimer?.invalidate()
  }
  
  // MARK: Overriten Methods
  
  public override func awakeFromNib() {
    super.awakeFromNib()
    self.setupView()
  }
  
  override public func prepareForInterfaceBuilder() {
    super.prepareForInterfaceBuilder()
    
    token = "eyJiIjoiMDg2NzM0NjQ3NjA0MTYxNmEiLCJ0IjoiQkFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFDR2tmNWxkZWZ3WEh3WmpvRmMzcnNEY0RINkpyY2pqOW0yS0liKyIsImNrIjoiNjhhZjY5YTRmOWE2NGU0YTkxZmE0NjBiZGExN2Y0MjciLCJlayI6IjA2ZWM1M2M3NDllNDQ3YTQ4ODAyNTdmNzNkYzNhYmZjIiwicnQiOiJyb3RhdGluZ19zeW1ib2xvZ3kifQ=="
  }

    // MARK: - SeatGeek Overrides

    func setupView() {
        // Kick off a single clock sync (this will be ignored if clock already synced)
        SecureEntryView.syncTime()

        addSubviews()
        makeConstraints()
        update()
    }

    func update() {
        switch entryData {
        case .none:
            state = state.reset()

            UIImage.getLoading { [weak self] (image) in
                guard let this = self else { return }
                this.loadingImage = image
                this.state = this.state.setLoadingImage(image)
                if case .loading = this.state {
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
            }

        case .some(.invalid):
            state = state.showError((message: errorMessage, icon: .alert))

        case .some(.rotatingPDF417(let token, let customerKey, let eventKey, let barcode)):
            let value = generateRotatingPDF417Value(
                token: token,
                customerKey: customerKey,
                eventKey: eventKey
            )

            state = state.showRotatingPDF417(
                rotatingBarcode: value,
                barcode: barcode,
                pdf417Subtitle: pdf417Subtitle,
                qrSubtitle: qrSubtitle,
                error: (message: errorMessage, icon: .alert)
            )

        case .some(.staticPDF417(let barcode)):
            state = state.showStaticPDF417(
                barcode: barcode,
                pdf417Subtitle: pdf417Subtitle,
                qrSubtitle: qrSubtitle,
                error: (message: errorMessage, icon: .alert)
            )

        case .some(.qrCode(let barcode)):
            state = state.showQRCode(
                barcode: barcode,
                subtitle: qrSubtitle,
                error: (message: errorMessage, icon: .alert)
            )
        }
    }
}

// MARK: - Public Methods
public extension SecureEntryView {
  
  /**
   Shows custom error message with icon.
   
   May be hidden by setting *token*.
   
   - Note:
   The maximal lenght is *60* symbols.
   */
  func showError(message: String, icon: UIImage? = nil) {
    state = state.showCustomError((
      message: message.truncate(length: 60, trailing: "..."),
      icon: icon ?? .alert
    ))
  }
}

// MARK: - Internal Methods
extension SecureEntryView {
  
  func addSubviews() {
    addSubview(barcodeView)
    addSubview(scanAnimationView)
    addSubview(errorView)
    addSubview(toggleButton)
  }
  
  func makeConstraints() {
    setContentHuggingPriority(.defaultHigh + 1, for: .vertical)
    setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
    
    setContentCompressionResistancePriority(.required, for: .horizontal)
    setContentCompressionResistancePriority(.required, for: .vertical)
    
    // MARK: Barcode View Constraints
    do {
      barcodeView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor).isActive = true
      barcodeView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor).isActive = true
      barcodeView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor).isActive = true
      barcodeView.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor).isActive = true
      
      barcodeView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
      barcodeView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
      
      let widthConstraint = barcodeView.widthAnchor.constraint(equalTo: widthAnchor)
      widthConstraint.priority = .defaultHigh
      widthConstraint.isActive = true
    }
    
    // MARK: Scan Animation View Constraints
    do {
      scanAnimationView.widthAnchor.constraint(equalTo: barcodeView.widthAnchor).isActive = true
      scanAnimationView.centerXAnchor.constraint(equalTo: barcodeView.centerXAnchor).isActive = true
      scanAnimationView.centerYAnchor.constraint(equalTo: barcodeView.centerYAnchor).isActive = true
      scanAnimationView.heightAnchor.constraint(
        equalTo: barcodeView.heightAnchor,
        constant: 16.0
        ).isActive = true
    }
    
    // MARK: Error View Constraints
    do {
      errorView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
      errorView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }
    
    // MARK : Toggle Button Constraints
    do {
      toggleButton.widthAnchor.constraint(equalTo: barcodeView.widthAnchor).isActive = true
      toggleButton.heightAnchor.constraint(equalTo: barcodeView.heightAnchor).isActive = true
      toggleButton.centerXAnchor.constraint(equalTo: barcodeView.centerXAnchor).isActive = true
      toggleButton.centerYAnchor.constraint(equalTo: barcodeView.centerYAnchor).isActive = true
    }
  }
  
  @objc
  func toggle(_ sender: Any) {
    self.state = self.state.toggle()
    
    guard !UIAccessibility.isVoiceOverRunning else {
      self.update()
      UIAccessibility.post(notification: .layoutChanged, argument: nil)
      return
    }
    
    UIView.transition(
      with: barcodeView,
      duration: 0.3,
      options: [.transitionCrossDissolve],
      animations: {
        self.update()
      },
      completion: { _ in UIAccessibility.post(notification: .layoutChanged, argument: nil) }
    )
  }
}

// MARK: - Private Methods
private extension SecureEntryView {
  
  func generateRotatingPDF417Value(token: String, customerKey: Data, eventKey: Data?) -> String {
    let totp = TOTP.shared
    let (customerNow, _) = totp.generate(secret: customerKey)
    
    let keys: [String]
    
    if let eventKey = eventKey {
      let (eventNow, eventTimestamp) = totp.generate(secret: eventKey)
      keys = [token, eventNow, customerNow, "\(eventTimestamp)"]
    }
    else {
      keys = [token, customerNow]
    }
    return keys.joined(separator: "::")
  }
}

public class SGSecureEntryView: SecureEntryView {

    // MARK: - Overrides
    override func setupView() {
        super.setupView()
        pdf417Subtitle = ""
        qrSubtitle = ""
        toggleButton.removeFromSuperview()
        scanAnimationView.removeFromSuperview()
        barcodeView.addSubview(scanningView)
        barcodeView.layer.cornerRadius = 0
    }

    override func update() {
        super.update()
        invalidateIntrinsicContentSize()
        onContentSizeChange?()

        let shouldShowAnimation = isShowingPDFBarcode

        guard shouldShowAnimation else {
            scanningView.alpha = 0
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            var scanningViewFrame = self.scanningView.frame
            scanningViewFrame.size.height = self.barcodeView.frame.size.height
            self.scanningView.frame = scanningViewFrame

            if self.scanningView.layer.animation(forKey: "slide") == nil,
                self.barcodeView.frame.size.width > 0 {

                let animation = self.scanningAnimation
                self.scanningView.layer.add(animation, forKey: "slide")
            }

            self.scanningView.alpha = 1
        }
    }

    // MARK: - Fresh

    var isShowingPDFBarcode: Bool {
        switch state {
        case .rotatingPDF417(_, _, _, _, _, let toggled):
            return !toggled
        case .staticPDF417(_, _, _):
            return true
        default:
            return false
        }
    }

    public var onContentSizeChange: (() -> ())?

    override public var intrinsicContentSize: CGSize {
        return isShowingPDFBarcode
            ? CGSize(width: 220.0, height: 85.0)
            : CGSize(width: 220.0, height: 160.0)
    }

    public func toggle() {
        toggle(self)
    }

    var scanningAnimation: CAAnimation {
        let parentWidth = barcodeView.frame.size.width
        let left = scanningView.frame.size.width * -2
        let right = parentWidth + scanningView.frame.size.width
        let delay = 1.25
        let tension: CGFloat = 30
        let friction: CGFloat = 22

        let leftToRightAnimation = CASpringAnimation(keyPath: "position.x")
        leftToRightAnimation.fromValue = left
        leftToRightAnimation.toValue = right
        leftToRightAnimation.stiffness = tension
        leftToRightAnimation.damping = friction
        leftToRightAnimation.beginTime = delay
        leftToRightAnimation.duration = leftToRightAnimation.settlingDuration
        leftToRightAnimation.fillMode = .forwards

        let rightToLeftAnimation = CASpringAnimation(keyPath: "position.x")
        rightToLeftAnimation.fromValue = right
        rightToLeftAnimation.toValue = left + 2
        rightToLeftAnimation.stiffness = tension
        rightToLeftAnimation.damping = friction
        rightToLeftAnimation.beginTime = leftToRightAnimation.beginTime + leftToRightAnimation.duration + delay
        rightToLeftAnimation.duration = rightToLeftAnimation.settlingDuration
        rightToLeftAnimation.fillMode = .forwards

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [leftToRightAnimation, rightToLeftAnimation]
        animationGroup.duration = rightToLeftAnimation.beginTime + rightToLeftAnimation.duration
        animationGroup.repeatCount = .infinity

        return animationGroup
    }

    public private(set) lazy var scanningView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        let width = 4
        view.frame = CGRect(x: width * -2, y: 0, width: width, height: 0)
        view.layer.cornerRadius = 2
        return view
    }()
}
