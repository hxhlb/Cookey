import UIKit

let defaultServerEndpoint: URL = {
    guard let string = Bundle.main.object(forInfoDictionaryKey: "CookeyDefaultServerEndpoint") as? String,
          let url = URL(string: string),
          url.scheme == "https",
          url.host() != nil
    else {
        fatalError("Info.plist must contain a valid HTTPS URL for CookeyDefaultServerEndpoint")
    }
    return url
}()

UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self),
)
