import AppKit

enum PanelBackground {
    static let image: NSImage? = {
        guard let url = BaristaResources.bundle.url(
            forResource: "CaffeineCrystals_Fibrous_10xDarkField",
            withExtension: "jpg"
        ),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()
}
