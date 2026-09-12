import SwiftUI

struct ContentView: View {
    @StateObject private var streamer = AudioStreamer()
    @AppStorage("pc_host") private var host: String = "192.168.1."
    @AppStorage("pc_port") private var portText: String = "50505"

    var body: some View {
        VStack(spacing: 24) {
            Text("PhoneMic")
                .font(.largeTitle).bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("PC IP address").font(.caption).foregroundColor(.secondary)
                TextField("192.168.1.23", text: $host)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .disabled(streamer.isStreaming)

                Text("Port").font(.caption).foregroundColor(.secondary)
                TextField("50505", text: $portText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .disabled(streamer.isStreaming)
            }
            .padding(.horizontal)

            Button(action: toggle) {
                Text(streamer.isStreaming ? "Stop" : "Start Streaming")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(streamer.isStreaming ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Text(streamer.status)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Keep this app open (screen can lock — audio background mode keeps it running). Playing music or getting notifications will NOT stop the mic stream.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 60)
    }

    private func toggle() {
        if streamer.isStreaming {
            streamer.stop()
        } else {
            let port = UInt16(portText) ?? 50505
            streamer.start(host: host, port: port)
        }
    }
}
