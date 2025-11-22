import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(radius: 4, y: 2)
            }

            VStack(spacing: 4) {
                Text("Capacity")
                    .font(.title.weight(.semibold))
                Text("Disk space at a glance.")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                AboutRow(label: "Version", value: appVersion)
                AboutRow(label: "Build", value: appBuild)
                AboutRow(label: "Developer", value: "George Babichev")
                AboutRow(label: "Copyright", value: "© \(Calendar.current.component(.year, from: Date())) George Babichev")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

                if let devPhoto = NSImage(named: "gbabichev") {
                    HStack(spacing: 12) {
                        Image(nsImage: devPhoto)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .offset(y: 3)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("George Babichev")
                                .font(.headline)
                        Link("georgebabichev.com", destination: URL(string: "https://georgebabichev.com")!)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Text("Capacity scans folders to show where your disk space is going. For accurate results on protected paths, grant Full Disk Access in System Settings.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 380)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
