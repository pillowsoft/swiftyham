// APRSView.swift — APRS view with map and message list.
// Split view: Map showing nearby stations, message inbox/outbox, station list.

import SwiftUI
import MapKit

struct APRSView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab: APRSTab = .map
    @State private var connectionState: APRSConnectionState = .disconnected
    @State private var isBeaconing: Bool = false
    @State private var messageText: String = ""
    @State private var messageRecipient: String = ""
    @State private var filterRadius: Double = 100
    @State private var mapPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.7, longitude: -72.8),
            span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        )
    )

    enum APRSTab: String, CaseIterable {
        case map = "Map"
        case messages = "Messages"
        case stations = "Stations"
        case weather = "Weather"
    }

    enum APRSConnectionState: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting..."
        case connected = "Connected"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Map
            mapPanel
                .frame(minWidth: 400)
                .layoutPriority(1)

            Divider()

            // Right: Tabs for messages, stations, weather
            rightPanel
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
        }
        .toolbar {
            toolbarContent
        }
        .navigationTitle("APRS")
    }

    // MARK: - Map Panel

    private var mapPanel: some View {
        VStack(spacing: 0) {
            Map(position: $mapPosition) {
                ForEach(APRSView.sampleStations) { station in
                    Annotation(station.callsign, coordinate: station.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: station.symbolImage)
                                .font(.caption)
                                .padding(4)
                                .background(station.isMoving ? Color.blue : Color.green)
                                .clipShape(Circle())
                                .foregroundStyle(.white)
                            Text(station.callsign)
                                .font(.system(.caption2, design: .monospaced))
                                .padding(.horizontal, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))

            // Map status bar
            HStack {
                Circle()
                    .fill(connectionState == .connected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(connectionState.rawValue)
                    .font(.caption)
                Spacer()
                Text("\(APRSView.sampleStations.count) stations in range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(APRSTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch selectedTab {
            case .map:
                stationListView
            case .messages:
                messageView
            case .stations:
                stationListView
            case .weather:
                weatherView
            }
        }
    }

    // MARK: - Message View

    private var messageView: some View {
        VStack(spacing: 0) {
            // Message list
            List(APRSView.sampleMessages) { message in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.isIncoming ? message.from : "To: \(message.to)")
                            .font(.system(.caption, design: .monospaced).bold())
                        Spacer()
                        Text(message.time, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(message.text)
                        .font(.caption)
                    if message.isAcked {
                        Text("ACK")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 2)
                .listRowBackground(message.isIncoming ? Color.blue.opacity(0.05) : Color.clear)
            }

            Divider()

            // Compose area
            HStack(spacing: 8) {
                TextField("Callsign", text: $messageRecipient)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 80)
                TextField("Message", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Button("Send") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(messageRecipient.isEmpty || messageText.isEmpty)
            }
            .padding(8)
        }
    }

    // MARK: - Station List

    private var stationListView: some View {
        List(APRSView.sampleStations) { station in
            HStack(spacing: 8) {
                Image(systemName: station.symbolImage)
                    .foregroundStyle(station.isMoving ? .blue : .green)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.callsign)
                        .font(.system(.caption, design: .monospaced).bold())
                    if let comment = station.comment {
                        Text(comment)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f km", station.distance))
                        .font(.system(.caption2, design: .monospaced))
                    Text(station.lastHeard, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weather View

    private var weatherView: some View {
        List(APRSView.sampleWeatherStations) { wx in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "cloud.sun")
                    Text(wx.callsign)
                        .font(.system(.caption, design: .monospaced).bold())
                    Spacer()
                    Text(String(format: "%.1f km", wx.distance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 2) {
                    GridRow {
                        Label("\(wx.temperature)\u{00B0}F", systemImage: "thermometer.medium")
                            .font(.caption)
                        Label("\(wx.windSpeed) mph \(wx.windDirection)", systemImage: "wind")
                            .font(.caption)
                    }
                    GridRow {
                        Label("\(wx.humidity)%", systemImage: "humidity")
                            .font(.caption)
                        Label(String(format: "%.1f mb", wx.pressure), systemImage: "barometer")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                connectionState = connectionState == .connected ? .disconnected : .connected
            } label: {
                Label(
                    connectionState == .connected ? "Disconnect" : "Connect",
                    systemImage: connectionState == .connected ? "wifi" : "wifi.slash"
                )
            }
        }

        ToolbarItem(placement: .automatic) {
            Toggle(isOn: $isBeaconing) {
                Label("Beacon", systemImage: "antenna.radiowaves.left.and.right")
            }
            .toggleStyle(.button)
        }

        ToolbarItem(placement: .automatic) {
            HStack(spacing: 4) {
                Text("Range:")
                    .font(.caption)
                Picker("Range", selection: $filterRadius) {
                    Text("50 km").tag(50.0)
                    Text("100 km").tag(100.0)
                    Text("200 km").tag(200.0)
                    Text("500 km").tag(500.0)
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }
        }
    }

    // MARK: - Sample Data

    struct SampleStation: Identifiable {
        let id: UUID
        let callsign: String
        let coordinate: CLLocationCoordinate2D
        let symbolImage: String
        let isMoving: Bool
        let comment: String?
        let distance: Double
        let lastHeard: Date
    }

    struct SampleMessage: Identifiable {
        let id: UUID
        let from: String
        let to: String
        let text: String
        let time: Date
        let isIncoming: Bool
        let isAcked: Bool
    }

    struct SampleWeatherStation: Identifiable {
        let id: UUID
        let callsign: String
        let distance: Double
        let temperature: Int
        let windSpeed: Int
        let windDirection: String
        let humidity: Int
        let pressure: Double
    }

    static let sampleStations: [SampleStation] = {
        let now = Date()
        return [
            SampleStation(id: UUID(), callsign: "W1AW-9", coordinate: CLLocationCoordinate2D(latitude: 41.714, longitude: -72.727), symbolImage: "car.fill", isMoving: true, comment: "Mobile in CT", distance: 2.3, lastHeard: now.addingTimeInterval(-120)),
            SampleStation(id: UUID(), callsign: "N1XYZ-1", coordinate: CLLocationCoordinate2D(latitude: 41.75, longitude: -72.65), symbolImage: "house.fill", isMoving: false, comment: "Home QTH Hartford", distance: 8.1, lastHeard: now.addingTimeInterval(-300)),
            SampleStation(id: UUID(), callsign: "KB1ABC-7", coordinate: CLLocationCoordinate2D(latitude: 41.55, longitude: -72.9), symbolImage: "figure.walk", isMoving: true, comment: "Hiking Blue Trail", distance: 15.4, lastHeard: now.addingTimeInterval(-60)),
            SampleStation(id: UUID(), callsign: "WX1CT", coordinate: CLLocationCoordinate2D(latitude: 41.8, longitude: -72.5), symbolImage: "cloud.sun.fill", isMoving: false, comment: "Weather station", distance: 22.7, lastHeard: now.addingTimeInterval(-600)),
            SampleStation(id: UUID(), callsign: "W1FD-5", coordinate: CLLocationCoordinate2D(latitude: 42.0, longitude: -72.8), symbolImage: "tent.fill", isMoving: false, comment: "Field Day site", distance: 33.2, lastHeard: now.addingTimeInterval(-1800)),
            SampleStation(id: UUID(), callsign: "N1MBL-9", coordinate: CLLocationCoordinate2D(latitude: 41.3, longitude: -73.1), symbolImage: "car.fill", isMoving: true, comment: nil, distance: 48.5, lastHeard: now.addingTimeInterval(-90)),
        ]
    }()

    static let sampleMessages: [SampleMessage] = {
        let now = Date()
        return [
            SampleMessage(id: UUID(), from: "W1AW-9", to: "N0CALL", text: "Are you on for Field Day?", time: now.addingTimeInterval(-300), isIncoming: true, isAcked: true),
            SampleMessage(id: UUID(), from: "N0CALL", to: "W1AW-9", text: "Yes! Setting up on 20m", time: now.addingTimeInterval(-240), isIncoming: false, isAcked: true),
            SampleMessage(id: UUID(), from: "KB1ABC-7", to: "N0CALL", text: "QSL via LOTW", time: now.addingTimeInterval(-120), isIncoming: true, isAcked: false),
            SampleMessage(id: UUID(), from: "N1XYZ-1", to: "N0CALL", text: "Net starts at 2000Z on 146.52", time: now.addingTimeInterval(-60), isIncoming: true, isAcked: true),
        ]
    }()

    static let sampleWeatherStations: [SampleWeatherStation] = [
        SampleWeatherStation(id: UUID(), callsign: "WX1CT", distance: 22.7, temperature: 72, windSpeed: 8, windDirection: "SW", humidity: 55, pressure: 1013.2),
        SampleWeatherStation(id: UUID(), callsign: "N1WX", distance: 45.3, temperature: 68, windSpeed: 12, windDirection: "W", humidity: 62, pressure: 1012.8),
        SampleWeatherStation(id: UUID(), callsign: "W1WX-13", distance: 67.1, temperature: 75, windSpeed: 5, windDirection: "S", humidity: 48, pressure: 1014.1),
    ]
}

#Preview {
    APRSView()
        .frame(width: 1000, height: 600)
        .environment(AppState())
}
