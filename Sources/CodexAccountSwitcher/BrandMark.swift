import AppKit
import SwiftUI

struct BrandMark: View {
    var body: some View {
        if let icon = NSImage(named: "MenuBarTemplate") {
            Image(nsImage: icon.templateImage)
                .resizable()
                .interpolation(.medium)
                .frame(width: 16, height: 16)
                .accessibilityLabel("Codex Account Switcher")
        } else {
            Image(systemName: "arrow.triangle.2.circlepath")
                .frame(width: 16, height: 16)
                .accessibilityLabel("Codex Account Switcher")
        }
    }
}

private extension NSImage {
    var templateImage: NSImage {
        let copy = copy() as? NSImage ?? self
        copy.isTemplate = true
        return copy
    }
}
