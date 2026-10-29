import SwiftUI

struct LearningShareView: View {
    private struct Published: Codable {
        let shareID: String; let revokeToken: String; let expiresAt: String; let path: String
    }
    @State private var snapshot: LearningShareSnapshot?
    @State private var published: Published?
    @State private var busy = false
    @State private var message = ""
    private let recordsKey = "learning.publishedProgressLinks.v1"
    var body: some View {
        Form {
            Section {
                Text("Publish a read-only snapshot for a friend, Grok, Claude or Codex. Anyone with the link can read it for 90 days. It does not update automatically.")
                Text("Includes completed lesson IDs, compiler marks, interview self-assessments and saved places. No code, drafts, attempt history, name or device identifier.").font(.footnote).foregroundStyle(.secondary)
                if let snapshot { Text("\(snapshot.completed.count) course items · \(snapshot.compilerVerified.count) compiler marks · \(snapshot.assessments.count) interview marks") }
                Button("Publish this progress snapshot") { Task { await publish() } }
                    .disabled(busy || snapshot == nil).accessibilityIdentifier("learning.share.publish")
                if busy { ProgressView() }
            }
            if let published, let url = URL(string: "https://gopherforge.app" + published.path) {
                Section("Published link") {
                    ShareLink("Share progress link", item: url)
                    Link("Open snapshot", destination: url)
                    Text("Expires \(published.expiresAt.prefix(10)). Opening this link does not change another person's progress.").font(.caption)
                    Button("Revoke this link", role: .destructive) { Task { await revoke(published) } }.disabled(busy)
                }
            }
            if !message.isEmpty { Section { Text(message).font(.footnote).textSelection(.enabled) } }
            Section {
                Text("Your normal learning progress remains local. Publishing a snapshot is separate from backup and does not certify knowledge. Do not post the link publicly unless you want your study record to be public.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Share learning progress").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            do { snapshot = try await LearningShareSnapshot.make() } catch { message = error.localizedDescription }
            if let data = UserDefaults.standard.data(forKey: recordsKey) { published = (try? JSONDecoder().decode([Published].self, from: data))?.last }
        }
    }
    @MainActor private func publish() async {
        guard let snapshot else { return }; busy = true; defer { busy = false }
        do {
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
            let transport = PlaygroundTransport(endpoint: URL(string: "https://gopherforge.app/api/progress-shares")!)
            let value: Published = try await transport.call(object)
            var records = UserDefaults.standard.data(forKey: recordsKey).flatMap { try? JSONDecoder().decode([Published].self, from: $0) } ?? []
            records.append(value)
            UserDefaults.standard.set(try JSONEncoder().encode(Array(records.suffix(30))), forKey: recordsKey)
            published = value; message = "Snapshot published. Source and drafts stayed on this device."
        } catch { message = error.localizedDescription }
    }
    @MainActor private func revoke(_ value: Published) async {
        busy = true; defer { busy = false }
        do {
            var request = URLRequest(url: URL(string: "https://gopherforge.app/api/progress-shares/" + value.shareID)!)
            request.httpMethod = "DELETE"; request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["revokeToken": value.revokeToken])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw URLError(.badServerResponse) }
            published = nil; message = "Link revoked. Local progress is unchanged."
        } catch { message = error.localizedDescription }
    }
}
