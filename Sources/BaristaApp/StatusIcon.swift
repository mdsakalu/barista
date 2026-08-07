import AppKit

enum StatusIcon {
    private static let activeSymbolName = "cup.and.saucer.steam.fill"
    private static let inactiveSymbolName = "cup.and.saucer.steam"

    static func image(active: Bool) -> NSImage {
        if active {
            return loadSymbol(named: activeSymbolName)
                ?? loadSymbol(named: "cup.and.saucer.fill")
                ?? fallbackSymbol(named: "cup.and.saucer.fill")
        }
        return loadSymbol(named: inactiveSymbolName)
            ?? loadSymbol(named: "cup.and.saucer")
            ?? fallbackSymbol(named: "cup.and.saucer")
    }

    private static func loadSymbol(named name: String) -> NSImage? {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        if let image = NSImage(named: NSImage.Name(name)) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        return nil
    }

    private static func fallbackSymbol(named name: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let configured = symbol.withSymbolConfiguration(config) ?? symbol
            let symbolSize = configured.size
            let origin = NSPoint(x: (size.width - symbolSize.width) / 2,
                                 y: (size.height - symbolSize.height) / 2 - 1)
            configured.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
