import SwiftUI

struct SettingsView: View {
    @AppStorage("apiBaseURL") private var apiBaseURL = Config.apiBaseURL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Настройки")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)

            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL API сервера")
                            .font(.subheadline.weight(.medium))
                        TextField("http://localhost:3000", text: $apiBaseURL)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Сервер", systemImage: "server.rack")
                } footer: {
                    Text("Адрес бэкенда для синхронизации заметок")
                }

                Section {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.tertiary)
                    }

                    HStack {
                        Text("Сборка")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Label("О приложении", systemImage: "info.circle")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
