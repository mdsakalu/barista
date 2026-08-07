import AppKit
import SwiftUI

struct AboutView: View {
    private let appName: String
    private let versionValue: String
    private let buildValue: String?
    private let repoURL = URL(string: "https://github.com/mdsakalu/barista")!
    private let repoLabel = "mdsakalu/barista"
    @State private var isHoveringLink = false

    init() {
        let bundle = Bundle.main
        appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Barista"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        versionValue = version ?? "dev"
        buildValue = build
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: StatusIcon.image(active: true))
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .foregroundStyle(.primary)
            Text(appName)
                .font(.title2)
                .fontWeight(.semibold)
            VStack(spacing: 4) {
                aboutInfoRow(label: "Version", value: versionValue)
                if let buildValue {
                    aboutInfoRow(label: "Build", value: buildValue)
                }
            }
            Button {
                NSWorkspace.shared.open(repoURL)
            } label: {
                HStack(spacing: 6) {
                    if let mark = GitHubMark.image {
                        Image(nsImage: mark)
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .padding(3)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                    }
                    Text(repoLabel)
                        .underline(isHoveringLink, color: Color.primary.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringLink = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private func aboutInfoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 54, alignment: .trailing)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

private enum GitHubMark {
    static let image: NSImage? = {
        guard let url = BaristaResources.bundle.url(forResource: "GitHub-Mark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()
}

