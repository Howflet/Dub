// SPIKE: Throwaway debug view for testing NSFileCoordinator-based file renaming
// AND FoundationModels text analysis with timeout handling.
// This is NOT production UI — delete this entire file's contents once both
// spike mechanisms are proven to work.
// Tracked by: spike/coordinator-rename-proof, spike/foundationmodels-proof
//
//  ContentView.swift
//  Dub
//
//  Created by Kevon Fletcher on 7/5/26.
//

import SwiftUI
import FoundationModels

struct ContentView: View {
    @State private var isAnalyzing = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            // SPIKE: Debug-only button — remove with the rest of this spike.
            Button("Test Rename") {
                performCoordinatedRename()
            }
            .buttonStyle(.borderedProminent)

            // SPIKE: Debug-only button — test FoundationModels analysis.
            Button("Test AI Describe") {
                isAnalyzing = true
                Task {
                    await performAIAnalysis()
                    isAnalyzing = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAnalyzing)

            if isAnalyzing {
                ProgressView("Analyzing…")
            }
        }
        .padding()
    }

    // MARK: - SPIKE: Coordinator-based rename proof-of-concept

    /// Creates a test file in the app's temp directory, then renames it using
    /// NSFileCoordinator, per dub-file-safety skill requirements.
    /// Uses temp dir to sidestep App Sandbox restrictions on ~/Desktop.
    private func performCoordinatedRename() {
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("dub_test.txt")
        let destinationURL = tempDir.appendingPathComponent("dub_test_renamed.txt")

        // Clean up any leftover files from a previous run so the spike is re-runnable.
        let fm = FileManager.default
        try? fm.removeItem(at: sourceURL)
        try? fm.removeItem(at: destinationURL)

        // Create the source file so there's something to rename.
        let created = fm.createFile(atPath: sourceURL.path, contents: Data("spike test content".utf8))
        guard created else {
            print("❌ SPIKE: Could not create test file at \(sourceURL.path)")
            return
        }
        print("📄 SPIKE: Created test file at \(sourceURL.path)")

        // NSFileCoordinator must be used for all renames (never raw FileManager.moveItem).
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?

        coordinator.coordinate(
            writingItemAt: sourceURL, options: .forMoving,
            writingItemAt: destinationURL, options: .forMoving,
            error: &coordinatorError
        ) { newSourceURL, newDestinationURL in
            do {
                coordinator.item(at: newSourceURL, willMoveTo: newDestinationURL)
                try FileManager.default.moveItem(at: newSourceURL, to: newDestinationURL)
                coordinator.item(at: newSourceURL, didMoveTo: newDestinationURL)

                print("✅ SPIKE: Rename succeeded — \(newSourceURL.lastPathComponent) → \(newDestinationURL.lastPathComponent)")
                print("   Source (gone): \(newSourceURL.path)")
                print("   Dest (exists): \(newDestinationURL.path)")
            } catch {
                print("❌ SPIKE: Rename failed inside coordinator block — \(error.localizedDescription)")
            }
        }

        if let coordinatorError {
            print("❌ SPIKE: NSFileCoordinator error — \(coordinatorError.localizedDescription)")
        }
    }

    // MARK: - SPIKE: FoundationModels analysis with timeout

    /// Sends a Dub-style naming prompt to the on-device FoundationModels model
    /// and enforces a 15-second timeout per REQUIREMENTS.md §4.2.
    ///
    /// NOTE: Image-based prompting (Attachment) requires macOS 27.0+.
    /// The current SDK (26.5) only supports text prompts. This spike uses a text
    /// description of an image to prove the session + timeout mechanism works.
    /// When the SDK is updated, swap the text description for:
    ///     Attachment(imageURL: someURL)
    private func performAIAnalysis() async {
        // 1. Check model availability before doing anything.
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            print("🤖 SPIKE: Model is available — proceeding with analysis.")
        case .unavailable(let reason):
            print("❌ SPIKE: Model unavailable — \(reason). Cannot run AI spike.")
            return
        @unknown default:
            print("❌ SPIKE: Unknown model availability state.")
            return
        }

        // 2. Run inference with a 15-second timeout (per REQUIREMENTS.md §4.2).
        //    Using a text description of an image since Attachment requires macOS 27.0+.
        let session = LanguageModelSession()

        do {
            let response = try await withThrowingTaskGroup(of: String.self) { group in
                // The real inference task.
                group.addTask {
                    let result = try await session.respond(
                        to: """
                        You are a file-naming assistant. Given a description of an \
                        image, output exactly 2-4 lowercase words separated by \
                        underscores that describe the primary subject. Do not include \
                        a file extension. Do not use punctuation, emoji, or non-ASCII \
                        characters. \
                        \
                        Description: A golden retriever playing in a sunny park with \
                        green grass and trees in the background. \
                        \
                        Output the filename only, nothing else.
                        """
                    )
                    return result.content
                }

                // Timeout task — 15 seconds.
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw TimeoutError()
                }

                // Return whichever finishes first; cancel the other.
                guard let first = try await group.next() else {
                    throw TimeoutError()
                }
                group.cancelAll()
                return first
            }

            print("✅ SPIKE: AI response — \"\(response)\"")

        } catch is TimeoutError {
            print("⏱️ SPIKE: AI timed out after 15 seconds — would fall back to metadata naming.")
        } catch {
            print("❌ SPIKE: AI analysis failed — \(error)")
        }
    }
}

/// Sentinel error used by the timeout racing pattern.
private struct TimeoutError: Error {}

#Preview {
    ContentView()
}
