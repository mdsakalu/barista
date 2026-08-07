import Foundation

enum BaristaResources {
    static let bundle: Bundle = {
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Barista_BaristaApp.bundle"),
           let appBundle = Bundle(url: resourceURL) {
            return appBundle
        }

        return Bundle.module
    }()
}
