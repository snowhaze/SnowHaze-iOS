# SnowHaze


SnowHaze is the first and only iOS browser that truly protects your data! Designed for best possible privacy and security and made to be easily accessible for both beginners and tech-savvy privacy enthusiasts.

SnowHaze offers everything from ad and tracking script blockers to a no-log VPN service.

Our primary focus has been on making SnowHaze the safest and most private browser on iOS. We also take small things seriously. What are these small things you ask? For example, SnowHaze will never establish any connection to any server without your explicit consent. Including our own. Visit [our homepage](https://snowhaze.com/) to see a complete list of SnowHaze's features.

Get SnowHaze for free on the [App Store](https://snowhaze.com/download).

## License

This project is currently *not* licensed.

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

An Apple ID, [CocoaPods](https://guides.cocoapods.org/using/getting-started.html#installation) and [Xcode 9.3](https://developer.apple.com/xcode/) are needed to build SnowHaze.


## Deployment

The following steps are needed to build SnowHaze:  

  * Clone the SnowHaze repository
  * Open the terminal and `cd` into the respective directory
  * Run  `pod install --repo-update`
  * In Xcode, open the file SnowHaze.xcworkspace
  * For both SnowHaze App and the SnowHaze VPN Widget, set an arbitrary and *unique* ["Bundle Identifier"](https://cocoacasts.com/what-are-app-ids-and-bundle-identifiers/)
  * Build and run SnowHaze in the simulator

In case you want to deploy SnowHaze to a real device:  

  * Use the same Apple ID on both devices (build machine and iOS device)
  * For both SnowHaze App and the SnowHaze VPN Widget, choose a [team](https://stackoverflow.com/questions/39524148/requires-a-development-team-select-a-development-team-in-the-project-editor-cod) (e.g. your Apple ID)
  * Build and run SnowHaze on your device


## Versioning

This is not our working repository and we only push versions to this repository that have made it through Apple's review process and will be released.


## Contributing

Please get in touch with us if you would like to contribute to SnowHaze. We would love to have you on board with us! As this is not our working repository, we cannot accept pull-requests on this repository.
 

## Authors

SnowHaze was created by Illotros GmbH, all rights reserved.


