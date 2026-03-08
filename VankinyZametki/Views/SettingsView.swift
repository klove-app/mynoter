import SwiftUI

struct SettingsView: View {
    @AppStorage("apiBaseURL") private var apiBaseURL = Config.apiBaseURL

    var body: some View {
        Form {
            Section("API Сервер") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("http://localhost:3000", text: $apiBaseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            }

            Section("О приложении") {
                HStack {
                    Text("Версия")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Настройки")
    }
}
