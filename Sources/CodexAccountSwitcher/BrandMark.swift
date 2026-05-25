import AppKit
import SwiftUI

struct BrandMark: View {
    var body: some View {
        if let icon = NSImage(named: "AppIcon") {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .accessibilityLabel("Codex Account Switcher")
        } else {
            Image(systemName: "arrow.triangle.2.circlepath")
                .frame(width: 18, height: 18)
                .accessibilityLabel("Codex Account Switcher")
        }
    }
}
