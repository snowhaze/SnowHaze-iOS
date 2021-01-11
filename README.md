# SnowHaze


SnowHaze is the first and only iOS browser that truly protects your data! Designed for best possible privacy and security and made to be easily accessible for both beginners and tech-savvy privacy enthusiasts.

SnowHaze offers everything from ad and tracking script blockers to a no-log VPN service.

Our primary focus has been on making SnowHaze the safest and most private browser on iOS. We also take small things seriously. What are these small things you ask? For example, SnowHaze will never establish any connection to any server without your explicit consent. Including our own servers. Visit [our homepage](https://snowhaze.com/) to see a complete list of SnowHaze's features.

Get SnowHaze for free on the [App Store](https://snowhaze.com/download).

## License

This project is licensed under the GPL license.

Disclaimer: The GPL license is *not* a free license and GPL licensed software is *not* free software. The GPL license restricts your rights to use software heavily. It is designed specifically to be incompatible with many other licenses and because of this we are bound to use the GPL license. Since the GPL license confines you to the GPL ecosystem, it contradicts the very essence of free software and thus we do not endorse it. Furthermore, the GPL license is for obscure reasons not compatible with Apps from the Apple App Store. Thus, the GPL license explicitly forbids you to use SnowHaze or any portions thereof for any projects distributed through the Apple App Store.

## Getting Started

The main purpose of this repository is to allow everybody to check SnowHaze's source code. This helps to find bugs easier and everybody can be assured that only best practices are used.

SnowHaze comes with an extensive database containing  

  * Sites known to support HTTPS 
  * Domains of ad networks
  * Known hosters of tracking scripts
  * Private sites
  * Dangerous sites
  * Unnecessary tracking parameters in URLs
  * Popular sites
  * Content blockers

Due to binding contracts, we are currently not allowed to publish the decrypted database. We have added a test database which only contains a few entries for each category. This allows you to test the functionality of the database.

However, for everyday use as a private browser, we still suggest downloading SnowHaze for free from the [App Store](https://snowhaze.com/download) with the newest database.


## Prerequisites

An Apple ID, [CocoaPods](https://guides.cocoapods.org/using/getting-started.html#installation) and [Xcode 12.3](https://developer.apple.com/xcode/) are needed to build SnowHaze.


## Deployment

The following steps are needed to build SnowHaze:  

  * Clone the SnowHaze repository
  * Open the terminal and `cd` into the respective directory
  * Run  `pod install`
  * In Xcode, open the file SnowHaze.xcworkspace
  * Set an arbitrary and *unique* ["Bundle Identifier"](https://cocoacasts.com/what-are-app-ids-and-bundle-identifiers/)
  * Build and run SnowHaze in the simulator

In case you want to deploy SnowHaze to a real device:  

  * Use the same Apple ID on both devices (build machine and iOS device)
  * Choose a [team](https://stackoverflow.com/questions/39524148/requires-a-development-team-select-a-development-team-in-the-project-editor-cod) (e.g. your Apple ID)
  * Build and run SnowHaze on your device


## Versioning

This is not our working repository and we only push versions to this repository that have made it through Apple's review process and will be released.


## Contributing

Please get in touch with us if you would like to contribute to SnowHaze. We would love to have you on board with us! As this is not our working repository, we cannot accept pull-requests on this repository.
 

## Authors

SnowHaze was created by Illotros GmbH, all rights reserved.


