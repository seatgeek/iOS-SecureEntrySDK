## Introduction

### SecureEntryView

The main view integrating the PDF417 into 3rd party applications is the `SecureEntryView`. It inherits from `UIView` and gives access to methods for controlling the underlying data and animation color.

Class definition for the view:

```swift
/**
* View displaying a rotating PDF417 or static PDF417 ticket.
*/
public final class SecureEntryView: UIView {}
```

## Installation

#### Cocoapods

1. Add the following to your PodFile
```
pod 'iOS-SecureEntrySDK', :git => 'https://github.com/ticketmaster/iOS-SecureEntrySDK.git'
```

2. Then run:
```
pod install
-- or --
pod update
```

#### Manually

1. Clone SecureEntrySDK from the git repository: https://github.com/ticketmaster/iOS-SecureEntrySDK
```
git clone https://github.com/ticketmaster/iOS-SecureEntrySDK
```

2. Add the `SecureEntryView.xcodeproj` from the cloned repository in your own Xcode project.
3. Link `Presence.framework` with your target
4. Add Copy Files Build Phase to include the framework to your application bundle

## Usage

| Storyboard Example | Result |
|:-------------:|:-----:|
| ![Storyboard](Storyboard.png "Storyboard") | ![Screenshot](Screenshot.png "Screenshot") |

### Adding the view

Simply include a UIView within your storyboard, and override it's class type to `SecureEntryView`, and link it to your code using an outlet:

```swift
@IBOutlet weak var secureEntryView: Presence.SecureEntryView!
```

or you may add it to a ViewController programmatically:

```swift
import Presence

...

var secureEntryView = Presence.SecureEntryView(frame: frameRect)
self.addSubview(secureEntryView)
```

---

### Position and size

The size of the rendered PDF417 displayed within the `SecureEntryView` is determined by the *width* of the view, however the height will be fixed at an aspect of 5:1, so to avoid any unexpected cropping or overlap with other elements, you should set the size, position, and aspect ratio of your `SecureEntryView` accordingly.

Since the `SecureEntryView` inherits from a standard `UIView`, you may use any methods associated with a view to alter its appearance, such as `setFrame`, etc.

---

### Syncing the time

#### `SecureEntryView.syncTime`

This method is used to begin a background time sync. This method is provided to allow apps to initiate a time sync before a `SecureEntryView` is ever instantiated/displayed.

**Note:** This is a static/singleton method, and must be called on the SecureEntryView class, and not a class instance.

```swift
// Initiates a background time sync 
SecureEntryView.syncTime()
```

---

### Applying the token

#### `setToken`

This method is used to apply a ticket's 'secure token' to the view. This will trigger a re-render of the view using the new token's data.

**Note:** You must call this method otherwise the view will remain blank/empty.

```swift
// set the token on the view 
secureEntryView.setToken(token: theNewToken, errorText: theErrorText)
```

##### Parameters
- **token** _(String)_: The token object obtained when fetching the user's tickets.
- **errorText** _(String)_: Sets a custom text string to display when an error occurs with the provided secure token.

---

### Change the branding color

#### `setBrandingColor`

Sets the branding color to the specified color value. This color is typically associated with a particular brand or team. Currently the branding color affects only the animation.

```swift
secureEntryView.setBrandingColor(color: theBrandingColor)
```

##### Parameters
- **color** _(UIColor)_: A color value to apply to the view.

---

### Change the branding color

#### `setPdf417Subtitle`

Creates a custom subtitle for the pdf417 variant of the SafeTix ticket. Will truncate if longer than the frame. Note: If set to "", the barcode subtitle will be hidden.

```swift
secureEntryView.setPdf417Subtitle(subtitleText: theSubtitleText)
```

##### Parameters
- **subtitleText** _(String)_: The text that will be displayed below the PDF417 barcode.

#### `setQrCodeSubtitle`

Creates a custom subtitle for the qr variant of the SafeTix ticket. Will truncate if longer than the frame. Note: If set to "", the barcode subtitle will be hidden.

```swift
secureEntryView.setQrCodeSubtitle(subtitleText: theSubtitleText)
```

##### Parameters
- **subtitleText** _(String)_: The text that will be displayed below the QR barcode.

#### `enableBrandedSubtitle`

Creates a custom subtitle for the qr variant of the SafeTix ticket. Will truncate if longer than the frame. Note: If set to "", the barcode subtitle will be hidden.

```swift
secureEntryView.enableBrandedSubtitle(enable: enabledValue)
```

##### Parameters
- **enable** _(Bool)_: Allows branding color on subtitle text to be enabled.

## Acknowledgements

SecureEntrySDK depends on the following open-source projects:

- **Kronos** by lyft (https://github.com/lyft/Kronos)
- **SwiftOTP** by Lachlan Bell (https://github.com/lachlanbell/SwiftOTP)
- **CryptoSwift** by Marcin Krzyzanowski (https://github.com/krzyzanowskim/CryptoSwift)
- **KeychainAccess** by Kishikawa Katsumi (https://github.com/kishikawakatsumi/KeychainAccess)
- **SwiftGif** by Arne Bahlo (https://github.com/swiftgif/SwiftGif)

This product includes software developed by "Marcin Krzyzanowski" (http://krzyzanowskim.com/).
