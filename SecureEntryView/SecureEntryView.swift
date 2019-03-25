//
//  SecureEntryView.swift
//  SecureEntryView
//
//  Created by Karl White on 11/30/18.
//  Copyright © 2018 Ticketmaster. All rights reserved.
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

extension String {
	/**
	Truncates the string to the specified length number of characters and appends an optional trailing string if longer.
	
	- Parameter length: A `String`.
	- Parameter trailing: A `String` that will be appended after the truncation.
	
	- Returns: A `String` object.
	*/
	func truncate(length: Int, trailing: String = "…") -> String {
		if self.count > length {
			return String(self.prefix(length)) + trailing
		} else {
			return self
		}
	}
}

internal struct SecureEntryConstants {
	struct Keys {
		static let MinOuterWidth = CGFloat(247)
		static let MinOuterHeight = CGFloat(160.0)
		static let MinRetWidth = CGFloat(247)
		static let MinRetHeight = CGFloat(50.0)
		static let MinStaticWidthHeight = CGFloat(126.0)
		static let MinErrorWidth = CGFloat(200.0)
		static let MinErrorHeight = CGFloat(120.0)
		
		static let RetBorderWidth = CGFloat(8.0)
		static let StaticBorderWidth = CGFloat(10.0) // QR is rendered with a transparent border already so effective border will be greater than this value
		
		static let ScanBoxWidth = CGFloat(12.0)
		static let ScanLineWidth = CGFloat(4.0)
		static let ScanAnimDuration = Double(1.5)
		static let ScanAnimStartDelay = Double(0.3)
		static let ScanBoxAnimStartDelay = Double(0.1)
		
		static let ToggleButtonMargin = CGFloat(-3.0)
		static let ToggleButtonWidthHeight = CGFloat(30.0)
		static let ToggleAnimDuration = Double(0.0)
	}
	
	struct Strings {
		static let DefaultErrorText = "Reload ticket"
	}
}

@IBDesignable public final class SecureEntryView: UIView {
	static fileprivate let clockGroup = DispatchGroup()
	static fileprivate var clockDate: Date?
	static fileprivate var clockOffset: TimeInterval?
	
	static public func syncTime( completed: ((_ synced: Bool) -> Void)? = nil ) {
		// Kick off a single clock sync
		#if !TARGET_INTERFACE_BUILDER
		DispatchQueue.global(qos: .default).async {
			SecureEntryView.clockGroup.wait()
			guard let _ = SecureEntryView.clockDate, let _ = SecureEntryView.clockOffset else {
				SecureEntryView.clockGroup.enter()
				DispatchQueue.global(qos: .background).async {
					Clock.sync(from: ClockConstants.TimePools.Apple, samples: 1, first: { date, offset in
						SecureEntryView.clockDate = date
						SecureEntryView.clockOffset = offset
						completed?(true)
						
						DispatchQueue.global(qos: .default).async {
							SecureEntryView.clockGroup.leave()
						}
					}, completion: nil)
				}
				return
			}
			completed?(true)
		}
		#endif //!TARGET_INTERFACE_BUILDER
	}
	
	fileprivate var originalToken: String?
	fileprivate var livePreviewInternal: Bool = false
	fileprivate var staticOnlyInternal: Bool = false
	fileprivate var brandingColorInternal: UIColor?
	fileprivate let timeInterval: TimeInterval = 15
	fileprivate var outerView: UIView?
	fileprivate var loadingImageView: UIImageView? //= WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
	fileprivate var retImageView: UIImageView?
	fileprivate var staticImageView: UIImageView?
	fileprivate var toggleStatic: Bool = false
	fileprivate var errorView: UIView?
	fileprivate var errorIcon: UIImageView?
	fileprivate var errorLabel: UILabel?
	fileprivate var timer: Timer? = nil
	fileprivate var type: BarcodeType = .pdf417
	
	@IBInspectable fileprivate var livePreview: Bool {
		get {
			return self.livePreviewInternal
		}
		set {
			self.livePreviewInternal = newValue
			self.setupView()
			self.update()
			self.start()
		}
	}
	@IBInspectable fileprivate var staticPreview: Bool {
		get {
			return self.staticOnlyInternal
		}
		set {
			self.staticOnlyInternal = newValue
			self.setupView()
			self.update()
			self.start()
		}
	}
	@IBInspectable fileprivate var brandingColor: UIColor? {
		get {
			return self.brandingColorInternal
		}
		set {
			self.brandingColorInternal = newValue
		}
	}

    override public var intrinsicContentSize: CGSize {
        if let imageView = retImageView, imageView.image != nil, !imageView.isHidden, imageView.alpha > 0 {
            return imageView.frame.size
        } else if let imageView = staticImageView {
            return imageView.frame.size
        }
        return self.frame.size
    }
	
	enum BarcodeType {
		
		case qr, aztec, pdf417
		
		var filter: CIFilter? {
			switch self {
			case .qr:
				let filter = CIFilter(name: "CIQRCodeGenerator")
				filter?.setValue("Q", forKey: "inputCorrectionLevel")
				return filter
				
			case .aztec:
				return CIFilter(name: "CIAztecCodeGenerator")
				
			case .pdf417:
				return CIFilter(name: "CIPDF417BarcodeGenerator")
			}
		}
	}
    
    public func syncTime( completed: ((_ synced: Bool) -> Void)? = nil ) {
        // Kick off a single clock sync
        #if !TARGET_INTERFACE_BUILDER
        DispatchQueue.global(qos: .default).async {
            SecureEntryView.clockGroup.wait()
            guard let _ = SecureEntryView.clockDate, let _ = SecureEntryView.clockOffset else {
                SecureEntryView.clockGroup.enter()
                DispatchQueue.global(qos: .background).async {
                    Clock.sync(from: ClockConstants.TimePools.Apple, samples: 1, first: { date, offset in
                        SecureEntryView.clockDate = date
                        SecureEntryView.clockOffset = offset
                        completed?(true)
                        
                        DispatchQueue.global(qos: .default).async {
                            SecureEntryView.clockGroup.leave()
                        }
                    }, completion: nil)
                }
                return
            }
            completed?(true)
        }
        #endif //!TARGET_INTERFACE_BUILDER
    }
	
    public func showError( text: String? ) {
        showError( text:text, icon:nil )
    }
	public func showError( text: String?, icon: UIImage? ) {
		self.errorLabel?.text = (text ?? "").truncate(length: 60, trailing: "...")
		self.errorIcon?.image = icon ?? UIImage(named: "Alert", in: Bundle(for: SecureEntryView.self), compatibleWith: nil)
		self.errorView?.isHidden = false
		self.loadingImageView?.isHidden = true
	}
	
	public func setToken( token: String! ) {
		self.setToken(token: token, errorText: nil)
	}
	public func setToken( token: String!, errorText: String? ) {
        guard ( self.originalToken == nil || self.originalToken != token ) else {
            self.start()
            return
        }

        // Parse token from supplied payload
        self.originalToken = token
        if token != nil {
            let newEntryData = EntryData(tokenString: token)

            // Stop renderer
            //self.stop()

            guard (newEntryData.getSegmentType() == .BARCODE || newEntryData.getSegmentType() == .ROTATING_SYMBOLOGY) else {
                self.showError( text: errorText ?? SecureEntryConstants.Strings.DefaultErrorText, icon: nil )
                return
            }

            self.entryData = newEntryData

            self.setupView()
            self.update()
            self.start()
        } else {
            self.showError( text: errorText ?? SecureEntryConstants.Strings.DefaultErrorText, icon: nil )
        }
	}
	
	public func setBrandingColor( color: UIColor! ) {
		brandingColor = color
	}
	
	/*
	// Only override draw() if you perform custom drawing.
	// An empty implementation adversely affects performance during animation.
	override func draw(_ rect: CGRect) {
	// Drawing code
	}
	*/
	
	
	/* Internal */
	override public init(frame: CGRect) {
		super.init(frame: frame)
		self.setup()
	}
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.setup()
	}
	
    @objc fileprivate func setup() {
        #if TARGET_INTERFACE_BUILDER
        guard livePreview == true else { return }
        #endif // TARGET_INTERFACE_BUILDER
        
        self.setupView()

		// Ensure animation resumes when returning from inactive
		#if swift(>=4.2)
		NotificationCenter.default.addObserver(self, selector: #selector(self.resume), name: UIApplication.didBecomeActiveNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.resume), name: UIApplication.willEnterForegroundNotification, object: nil)
		#elseif swift(>=4.0)
		NotificationCenter.default.addObserver(self, selector: #selector(self.resume), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.resume), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
		#endif

        // Kick off a single clock sync (this will be ignored if clock already synced)
        SecureEntryView.syncTime()
    }
    
	deinit {
		stop()
	}
	
	fileprivate(set) var flipped = false {
		didSet {
			retImageView?.transform = CGAffineTransform(scaleX: 1.0, y: flipped ? -1.0 : 1.0);
		}
	}
	
	fileprivate(set) var entryData: EntryData? {
		didSet {
			#if TARGET_INTERFACE_BUILDER
			guard livePreview == true else { return }
			#endif // TARGET_INTERFACE_BUILDER
			
			guard let entryData = entryData, (entryData.getSegmentType() == .BARCODE || entryData.getSegmentType() == .ROTATING_SYMBOLOGY) else {
				stop()
				return
			}
			update()
			//start()
		}
	}
	
	var staticMessage: String? {
		didSet {
			if staticImageView == nil || errorView == nil {
				setupView()
			}
			guard ( oldValue == nil || oldValue != staticMessage ) else {
				return
			}
			
			if let staticImageView = self.staticImageView {
				// Generate & scale the Static barcode (QR)
				if let staticFilter = CIFilter(name: "CIQRCodeGenerator") {
					staticFilter.setValue("Q", forKey: "inputCorrectionLevel")
					staticFilter.setValue(staticMessage?.dataUsingUTF8StringEncoding, forKey: "inputMessage")
					if let scaled = staticFilter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12.0, y: 12.0)) {
						let image = UIImage(ciImage: scaled, scale: 4.0, orientation: .up)
						
						// Add inset padding
						let scaleFactor = ( SecureEntryConstants.Keys.MinStaticWidthHeight + ( SecureEntryConstants.Keys.StaticBorderWidth * 2 ) ) / staticImageView.frame.width
						let insetValue = SecureEntryConstants.Keys.StaticBorderWidth * scaleFactor
						let insets = UIEdgeInsets(top: insetValue, left: insetValue, bottom: insetValue, right: insetValue)
						UIGraphicsBeginImageContextWithOptions( CGSize(width: image.size.width + insets.left + insets.right, height: image.size.height + insets.top + insets.bottom), false, image.scale)
						let _ = UIGraphicsGetCurrentContext()
						let origin = CGPoint(x: insets.left, y: insets.top)
						image.draw(at: origin)
						let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
						UIGraphicsEndImageContext()
						
						// Apply the image
						staticImageView.image = imageWithInsets
						
					} else {
						staticImageView.image = nil
						return
					}
				}
			}
		}
	}
	
	var fullMessage: String? {
		didSet {
			if retImageView == nil || staticImageView == nil || errorView == nil {
				setupView()
			}
			guard ( oldValue == nil || oldValue != fullMessage ) else {
				return
			}
			
			//DispatchQueue.main.async {
			#if !TARGET_INTERFACE_BUILDER
			guard let fullMessage = self.fullMessage, let segmentType = self.entryData?.getSegmentType() else {
				self.retImageView?.image = nil
				self.staticImageView?.image = nil
				return
			}
			#else
			// Allow interface builder to display dummy sample
			let segmentType = self.staticOnlyInternal ? EntryData.SegmentType.BARCODE : EntryData.SegmentType.ROTATING_SYMBOLOGY
			guard let fullMessage = self.fullMessage else { return }
			#endif //TARGET_INTERFACE_BUILDER
			
			if segmentType == .ROTATING_SYMBOLOGY, let retImageView = self.retImageView {
				// Generate & scale the RET barcode (PDF417)
				if let retFilter = CIFilter(name: "CIPDF417BarcodeGenerator") {
					retFilter.setValue(fullMessage.dataUsingUTF8StringEncoding, forKey: "inputMessage")
                    if let barcodeImage = retFilter.outputImage {
                        let generatedImageSize = barcodeImage.extent.integral.size
                        let maxSize = CGSize(width: 272, height: 54)

                        let screenScale: CGFloat = 1 // SCREEN_SCALE if we need to, but if views are pixel aliged we won't
                        let maxSizeInPixels = CGSize(width: maxSize.width * screenScale, height: maxSize.height * screenScale)
                        var xScale: CGFloat = maxSizeInPixels.width / generatedImageSize.width
                        let xSize = CGSize(width: generatedImageSize.width * xScale, height: generatedImageSize.height * xScale)
                        if xSize.height > maxSizeInPixels.height {
                            let furtherScale = maxSizeInPixels.height / xSize.height
                            xScale *= furtherScale
                        }

                        var yScale = maxSizeInPixels.height / generatedImageSize.height
                        let ySize = CGSize(width: generatedImageSize.width * yScale, height: generatedImageSize.height * yScale)
                        if ySize.width > maxSizeInPixels.width {
                            let furtherScale = maxSizeInPixels.width / ySize.width
                            yScale *= furtherScale
                        }

                        let scale = min(xScale, yScale)
                        let imageByTransform = barcodeImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                        let image =  UIImage(ciImage: imageByTransform)

                        // Apply the image
                        retImageView.image = image

                        self.flipped = !self.flipped
                    } else {
						retImageView.image = nil
						return
					}
				}
			}
			
			// Always generate QR code (to allow RET<>QR switching)
			if /*segmentType == .BARCODE,*/ let staticImageView = self.staticImageView {
				// Generate & scale the Static barcode (QR)
				if let staticFilter = CIFilter(name: "CIQRCodeGenerator") {
					staticFilter.setValue("Q", forKey: "inputCorrectionLevel")
					staticFilter.setValue(staticMessage?.dataUsingUTF8StringEncoding, forKey: "inputMessage")
					if let scaled = staticFilter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12.0, y: 12.0)) {
						let image = UIImage(ciImage: scaled, scale: 4.0, orientation: .up)
						
						// Add inset padding
						let scaleFactor = ( SecureEntryConstants.Keys.MinStaticWidthHeight + ( SecureEntryConstants.Keys.StaticBorderWidth * 2 ) ) / staticImageView.frame.width
						let insetValue = SecureEntryConstants.Keys.StaticBorderWidth * scaleFactor
						let insets = UIEdgeInsets(top: insetValue, left: insetValue, bottom: insetValue, right: insetValue)
						UIGraphicsBeginImageContextWithOptions( CGSize(width: image.size.width + insets.left + insets.right, height: image.size.height + insets.top + insets.bottom), false, image.scale)
						let _ = UIGraphicsGetCurrentContext()
						let origin = CGPoint(x: insets.left, y: insets.top)
						image.draw(at: origin)
						let imageWithInsets = UIGraphicsGetImageFromCurrentImageContext()
						UIGraphicsEndImageContext()
						
						// Apply the image
						staticImageView.image = imageWithInsets
						
					} else {
						staticImageView.image = nil
						return
					}
				}
			}
			//}
		}
	}
	
	@objc public func toggleMode(_ sender: AnyObject) {
		// Only rotating symbology may be toggled
		if self.entryData?.getSegmentType() == .ROTATING_SYMBOLOGY {
			self.toggleStatic = !self.toggleStatic
		}
		toggleUpdate()
	}
	
	@objc fileprivate func toggleModeOff() {
		self.toggleStatic = false
		toggleUpdate()
	}
	
	@objc fileprivate func toggleUpdate() {
        // Only rotating symbology may be toggled
        if self.entryData?.getSegmentType() == .ROTATING_SYMBOLOGY {
            if true == self.toggleStatic {
                self.update()
                self.retImageView?.isHidden = false
                self.retImageView?.alpha = 1
                self.staticImageView?.isHidden = false
                self.staticImageView?.alpha = 0
                self.staticImageView?.center.y = ( self.outerView?.bounds.size.height ?? 0 ) * 2
                UIView.animate( withDuration:SecureEntryConstants.Keys.ToggleAnimDuration * 1.5, delay: 0,
                               usingSpringWithDamping: 0.7,
                               initialSpringVelocity: 1.0,
                               options: [.curveEaseOut], animations: {
                    self.retImageView?.alpha = 0
                    
                    self.staticImageView?.center.y = ( self.outerView?.bounds.size.height ?? 0 ) / 2
                    self.staticImageView?.alpha = 1
                }, completion: { done in
					if true == self.toggleStatic {
						//self.stopAnimation()
						self.update()
					}
                })
            } else {
                self.update()
                self.retImageView?.isHidden = false
                self.retImageView?.alpha = 0
                self.staticImageView?.isHidden = false
                self.staticImageView?.alpha = 1
                self.staticImageView?.center.y = ( self.outerView?.bounds.size.height ?? 0 ) / 2
                UIView.animate( withDuration:SecureEntryConstants.Keys.ToggleAnimDuration * 1.5, delay: 0,
                                usingSpringWithDamping: 0.7,
                                initialSpringVelocity: 1.0,
                                options: [.curveEaseOut], animations: {
                    self.retImageView?.alpha = 1
                    
                    self.staticImageView?.center.y = ( self.outerView?.bounds.size.height ?? 0 ) * 2
                    self.staticImageView?.alpha = 0
                }, completion: { done in

                })
            }
        }
    }
	
	@objc fileprivate func setupView() {
		#if TARGET_INTERFACE_BUILDER
		guard livePreview == true else { return }
		#endif // TARGET_INTERFACE_BUILDER
		
		var outerRect = self.frame
		var retRect = outerRect
		var staticRect = self.frame
		var errorRect = self.frame
		var buttonRect = self.frame
		let sizeFactor = SecureEntryConstants.Keys.MinOuterWidth / outerRect.size.width
		
		outerRect.size.width = max(SecureEntryConstants.Keys.MinOuterWidth, outerRect.size.width)
		outerRect.size.height = max(SecureEntryConstants.Keys.MinOuterHeight, outerRect.size.height)
		
		retRect.size.width = max(SecureEntryConstants.Keys.MinRetWidth, outerRect.size.width)
		retRect.size.height = max(SecureEntryConstants.Keys.MinRetHeight, retRect.size.width / 4.0)
		
		staticRect.size.width = max(SecureEntryConstants.Keys.MinStaticWidthHeight, outerRect.size.height)
		staticRect.size.height = max(SecureEntryConstants.Keys.MinStaticWidthHeight, staticRect.size.width)
		
		errorRect.size.width = max(SecureEntryConstants.Keys.MinErrorWidth, outerRect.size.width * (SecureEntryConstants.Keys.MinErrorWidth/SecureEntryConstants.Keys.MinOuterWidth))
		errorRect.size.height = max(SecureEntryConstants.Keys.MinErrorHeight, errorRect.size.width * (SecureEntryConstants.Keys.MinErrorHeight/SecureEntryConstants.Keys.MinErrorWidth))
		
		buttonRect.size.width = SecureEntryConstants.Keys.ToggleButtonWidthHeight
		buttonRect.size.height = SecureEntryConstants.Keys.ToggleButtonWidthHeight
		buttonRect.origin.x = outerRect.size.width - ( buttonRect.size.width + SecureEntryConstants.Keys.ToggleButtonMargin )
		buttonRect.origin.y = outerRect.size.height - ( buttonRect.size.height + SecureEntryConstants.Keys.ToggleButtonMargin )
		
		if outerView != nil {} else {
			outerView = UIView(frame: outerRect);
			if let outerView = outerView {
				outerView.layer.masksToBounds = true
				self.addSubview(outerView)
				
				outerView.center.x = self.bounds.width / 2.0
				outerView.center.y = self.bounds.height / 2.0
				outerView.translatesAutoresizingMaskIntoConstraints = false
				outerView.widthAnchor.constraint(equalToConstant: outerRect.width).isActive = true
				outerView.heightAnchor.constraint(equalToConstant: outerRect.height).isActive = true
				outerView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
				outerView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
				
				if loadingImageView != nil {} else {
					loadingImageView = UIImageView(frame: retRect)
					if let loadingImageView = self.loadingImageView {
						loadingImageView.frame = retRect
						loadingImageView.layer.masksToBounds = true
						loadingImageView.layer.backgroundColor = UIColor.white.cgColor
						loadingImageView.layer.borderWidth = 0
						loadingImageView.layer.cornerRadius = 4
						
						if let loadingData = NSDataAsset(name: "Loading", bundle: Bundle(for: SecureEntryView.self)) {
							DispatchQueue.global().async {
								let image = UIImage.gif(data: loadingData.data)
								DispatchQueue.main.async {
									self.loadingImageView?.image = image
								}
							}
						}
						
						loadingImageView.isHidden = false
						outerView.addSubview(loadingImageView)
						loadingImageView.center.x = self.bounds.width / 2.0
						loadingImageView.center.y = self.bounds.height / 2.0
						loadingImageView.translatesAutoresizingMaskIntoConstraints = false
						loadingImageView.widthAnchor.constraint(equalToConstant: retRect.width).isActive = true
						loadingImageView.heightAnchor.constraint(equalToConstant: retRect.height).isActive = true
						loadingImageView.centerXAnchor.constraint(equalTo: outerView.centerXAnchor).isActive = true
						loadingImageView.centerYAnchor.constraint(equalTo: outerView.centerYAnchor).isActive = true
					}
				}
				
				if staticImageView != nil {} else {
					staticImageView = UIImageView(frame: staticRect)
					if let staticImageView = staticImageView {
						staticImageView.layer.masksToBounds = true
						staticImageView.layer.backgroundColor = UIColor.white.cgColor
						staticImageView.layer.borderWidth = 0
						staticImageView.layer.cornerRadius = 4
						staticImageView.isHidden = true
						outerView.addSubview(staticImageView)
						
						staticImageView.center.x = self.bounds.width / 2.0
						staticImageView.center.y = self.bounds.height / 2.0
						staticImageView.translatesAutoresizingMaskIntoConstraints = false
						staticImageView.widthAnchor.constraint(equalToConstant: staticRect.width).isActive = true
						staticImageView.heightAnchor.constraint(equalToConstant: staticRect.height).isActive = true
						staticImageView.centerXAnchor.constraint(equalTo: outerView.centerXAnchor).isActive = true
						staticImageView.centerYAnchor.constraint(equalTo: outerView.centerYAnchor).isActive = true
					}
				}
				
				if retImageView != nil {} else {
					retImageView = UIImageView()
					if let retImageView = retImageView {
						retImageView.layer.masksToBounds = true
						retImageView.layer.backgroundColor = UIColor.white.cgColor
						retImageView.isHidden = true
                        retImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
                        retImageView.setContentCompressionResistancePriority(.required, for: .vertical)
                        retImageView.setContentHuggingPriority(.required, for: .horizontal)
                        retImageView.setContentHuggingPriority(.required, for: .vertical)
						outerView.addSubview(retImageView)

						retImageView.translatesAutoresizingMaskIntoConstraints = false
						retImageView.centerXAnchor.constraint(equalTo: outerView.centerXAnchor).isActive = true
						retImageView.centerYAnchor.constraint(equalTo: outerView.centerYAnchor).isActive = true
					}

                    if scanningView.superview == nil {
                        retImageView?.addSubview(scanningView)
                    }
				}
				
				if errorView != nil {} else {
					errorView = UIView(frame: errorRect)
					if let errorView = errorView {
						errorView.layer.masksToBounds = false
						errorView.layer.backgroundColor = UIColor.white.cgColor
						errorView.layer.borderWidth = 0
						errorView.layer.cornerRadius = 4
						errorView.isHidden = true
						outerView.addSubview(errorView)
						
						errorView.center.x = self.bounds.width / 2.0
						errorView.center.y = self.bounds.height / 2.0
						errorView.translatesAutoresizingMaskIntoConstraints = false
						errorView.widthAnchor.constraint(equalToConstant: errorRect.width).isActive = true
						errorView.heightAnchor.constraint(equalToConstant: errorRect.height).isActive = true
						errorView.centerXAnchor.constraint(equalTo: outerView.centerXAnchor).isActive = true
						errorView.centerYAnchor.constraint(equalTo: outerView.centerYAnchor).isActive = true
						
						if errorIcon != nil {} else {
							var iconRect = errorRect;
							iconRect.size.height = max(32, ( errorRect.size.height / 2 ) - 10)
							iconRect.size.width = iconRect.size.height
							errorIcon = UIImageView(frame: iconRect)
							if let errorIcon = errorIcon {
								errorIcon.layer.masksToBounds = true
								errorIcon.image = UIImage(named: "Alert", in: Bundle(for: SecureEntryView.self), compatibleWith: nil)
								errorView.addSubview(errorIcon)
								
								errorIcon.center.x = self.bounds.width / 2.0
								errorIcon.center.y = self.bounds.height / 2.0
								errorIcon.translatesAutoresizingMaskIntoConstraints = false
								errorIcon.heightAnchor.constraint(lessThanOrEqualToConstant: iconRect.size.height).isActive = true
								errorIcon.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
								errorIcon.addConstraint(NSLayoutConstraint(item: errorIcon, attribute: .height, relatedBy: .equal, toItem: errorIcon, attribute: .width, multiplier: 1, constant: 0))
								errorIcon.centerXAnchor.constraint(equalTo: errorView.centerXAnchor).isActive = true
								errorIcon.topAnchor.constraint(greaterThanOrEqualTo: errorView.topAnchor, constant: 16).isActive = true
								errorIcon.topAnchor.constraint(lessThanOrEqualTo: errorView.topAnchor, constant: (errorRect.size.height * 0.5) - (iconRect.size.height * 0.5) )
							}
						}
						
						if errorLabel != nil {} else {
							var textRect = errorRect;
							textRect.size.width -= 20
							textRect.size.height /= 2
							errorLabel = UILabel(frame: textRect)
							if let errorLabel = errorLabel {
								errorLabel.layer.masksToBounds = true
								errorView.addSubview(errorLabel)
								
								errorLabel.numberOfLines = 0
								errorLabel.center.x = self.bounds.width / 2.0
								errorLabel.center.y = self.bounds.height / 2.0
								errorLabel.translatesAutoresizingMaskIntoConstraints = false
								
								errorLabel.widthAnchor.constraint(equalToConstant: textRect.size.width).isActive = true
								errorLabel.heightAnchor.constraint(lessThanOrEqualToConstant: errorRect.size.height * 0.6).isActive = true
								errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
								errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 10).isActive = true
								errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -10).isActive = true
								errorLabel.centerXAnchor.constraint(equalTo: errorView.centerXAnchor).isActive = true
								errorLabel.topAnchor.constraint(equalTo: errorIcon!.bottomAnchor, constant: 8).isActive = true
								errorLabel.bottomAnchor.constraint(lessThanOrEqualTo: errorView.bottomAnchor, constant: -10).isActive = true
								let pushConstraint = errorLabel.bottomAnchor.constraint(equalTo: errorView.bottomAnchor, constant: -errorRect.size.height * 0.3)
								pushConstraint.isActive = true
								pushConstraint.priority = UILayoutPriority(rawValue: 1)
								
								errorLabel.font = UIFont(descriptor: errorLabel.font.fontDescriptor, size: 4 + (8*(1/sizeFactor)))
								errorLabel.textColor = UIColor.darkGray
								errorLabel.textAlignment = .center
							}
						}
					}
				}
			}
		}
		
		#if TARGET_INTERFACE_BUILDER
		retImageView?.isHidden = staticOnlyInternal ? true : false
		toggleButton?.isHidden = staticOnlyInternal ? true : false
		scanAnimBox?.isHidden = staticOnlyInternal ? true : false
		scanAnimLine?.isHidden = staticOnlyInternal ? true : false
		staticImageView?.isHidden = staticOnlyInternal ? false : true
		loadingImageView?.isHidden = true
		errorView?.isHidden = true
		//self.entryData = EntryData(tokenString: "eyJiIjoiNzgxOTQxNjAzMDAxIiwidCI6IlRNOjowMzo6MjAxeXRmbmllN2tpZmxzZ2hncHQ5ZDR4N2JudTljaG4zYWNwdzdocjdkOWZzc3MxcyIsImNrIjoiMzRkNmQyNTNiYjNkZTIxOTFlZDkzMGY2MmFkOGQ0ZDM4NGVhZTVmNSJ9")
		self.staticMessage = "\(staticOnlyInternal)"
		self.fullMessage = "THIS IS A SAMPLE SECURE ENTRY VALUE (Unique ID: \(Date().description(with: Locale.current).hashValue))"
		self.start()
		#endif // TARGET_INTERFACE_BUILDER
	}
	
	@objc fileprivate func update() {
		guard let entryData = self.entryData else {
			return
		}
		
		retImageView?.isHidden = true
		staticImageView?.isHidden = true
		errorView?.isHidden = true
		
		if ( self.toggleStatic == false ) && ( self.entryData?.getSegmentType() == .ROTATING_SYMBOLOGY ) {
			if TOTP.shared == nil {
				TOTP.update()
			}
			
			guard let totp = TOTP.shared else {
				return
			}
			
			
			retImageView?.isHidden = false
			loadingImageView?.isHidden = true
			
			// Get simple barcoee message
			staticMessage = self.entryData?.getBarcode()
			
			// Customer key is always required, so fetch it
			guard let customerNow = totp.generate(secret: self.entryData?.getCustomerKey() ?? Data()) else {
				return
			}
			
			// Event key may not be provided, so only generate if available
			if let eventKey = self.entryData?.getEventKey() {
				guard let eventNow = totp.generate(secret: eventKey) else {
					return
				}
				
				fullMessage = (self.entryData?.getToken() ?? "") + "::" + eventNow + "::" + customerNow
			} else {
				fullMessage = (self.entryData?.getToken() ?? "") + "::" + customerNow
			}
		} else if ( self.toggleStatic == true ) || ( entryData.getSegmentType() == .BARCODE ) {
			staticImageView?.isHidden = false
			loadingImageView?.isHidden = true
			staticMessage = self.entryData?.getBarcode()
		} else {
			errorView?.isHidden = false
		}
        invalidateIntrinsicContentSize()
        onContentSizeChange?()

        if let retImageView = retImageView {
            var scanningViewFrame = scanningView.frame
            scanningViewFrame.size.height = retImageView.frame.size.height
            scanningView.frame = scanningViewFrame

            if scanningView.layer.animation(forKey: "slide") == nil, retImageView.frame.size.width > 0 {
                let animation = scanningAnimation
                scanningView.layer.add(animation, forKey: "slide")
            }
        }
	}
	
	@objc fileprivate func start() {
		self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
            self?.update()
        })
		self.timer?.tolerance = 0.25
	}
	
	@objc fileprivate func resume() {
		self.timer?.invalidate()
		self.timer = nil
		self.start()
	}
	
	@objc fileprivate func stop() {
        self.timer?.invalidate()
		self.timer = nil
	}

    public var onContentSizeChange: (() -> ())?

    var scanningAnimation: CAAnimation {
        let parentWidth = retImageView?.frame.size.width ?? scanningView.frame.size.width
        let left = 0
        let right = parentWidth - scanningView.frame.size.width
        let duration = 1.5
        let timing = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.2, 1)
        let delay = 0.75

        let leftToRightAnimation = CABasicAnimation(keyPath: "position.x")
        leftToRightAnimation.fromValue = left
        leftToRightAnimation.toValue = right
        leftToRightAnimation.duration = duration
        leftToRightAnimation.timingFunction = timing
        leftToRightAnimation.beginTime = delay
        leftToRightAnimation.fillMode = .forwards

        let rightToLeftAnimation = CABasicAnimation(keyPath: "position.x")
        rightToLeftAnimation.fromValue = right
        rightToLeftAnimation.toValue = left + 2
        rightToLeftAnimation.duration = duration
        rightToLeftAnimation.timingFunction = timing
        rightToLeftAnimation.beginTime = leftToRightAnimation.beginTime + leftToRightAnimation.duration + delay
        rightToLeftAnimation.fillMode = .forwards

        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [leftToRightAnimation, rightToLeftAnimation]
        animationGroup.duration = delay + duration + delay + duration
        animationGroup.repeatCount = .infinity

        return animationGroup
    }

    lazy var scanningView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.4
        view.frame = CGRect(x: 0, y: 0, width: 4, height: 0)
        view.layer.cornerRadius = 2
        return view
    }()
}
