//
//  DownloadProgressView.swift
//  Mapbox_tutorial
//
//  Created by yousanflics on 12/9/25.
//

import SwiftUI

struct DownloadProgressView: View {
    let progress: Double
    let stage: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Downloading Offline Region")
                    .font(.headline)

                Spacer()
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)

                HStack {
                    Text(stage)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }

            // Cancel Button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Download Complete View

struct DownloadCompleteView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Download Complete!")
                .font(.headline)

            Text("The offline region has been saved successfully.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Download Error View

struct DownloadErrorView: View {
    let error: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Download Failed")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }

                Button(action: onRetry) {
                    Text("Retry")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Previews

#Preview("Progress") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        DownloadProgressView(
            progress: 0.65,
            stage: "Downloading tiles...",
            onCancel: {}
        )
    }
}

#Preview("Complete") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        DownloadCompleteView(onDismiss: {})
    }
}

#Preview("Error") {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()

        DownloadErrorView(
            error: "Network connection lost",
            onRetry: {},
            onDismiss: {}
        )
    }
}
