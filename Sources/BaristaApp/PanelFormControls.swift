import AppKit
import SwiftUI

struct OutlineCheckboxStyle: ToggleStyle {
    let outlineOpacity: Double

    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.primary.opacity(outlineOpacity), lineWidth: 1)
                        .frame(width: 14, height: 14)
                    if configuration.isOn {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.primary.opacity(0.9))
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(NSColor.windowBackgroundColor))
                    }
                }
                configuration.label
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TranslucentTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) private var colorScheme

    func _body(configuration: TextField<_Label>) -> some View {
        let strokeOpacity: Double = colorScheme == .dark ? 0.25 : 0.2
        configuration
            .textFieldStyle(.plain)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

struct RadioRow: View {
    let title: String
    let isSelected: Bool
    let outlineOpacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(outlineOpacity), lineWidth: 1)
                        .frame(width: 12, height: 12)
                    if isSelected {
                        Circle()
                            .fill(Color.primary.opacity(0.9))
                            .frame(width: 6, height: 6)
                    }
                }
                Text(title)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum SessionModePanel {
    static let height: CGFloat = 140
}

struct SectionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct SectionHeightReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: SectionHeightKey.self, value: proxy.size.height)
        }
    }
}

