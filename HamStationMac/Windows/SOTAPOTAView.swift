// SOTAPOTAView.swift — SOTA/POTA tracking view
// Map with pins + filterable list, activation history.

import SwiftUI
import MapKit

struct SOTAPOTAView: View {
    @State private var selectedTab: ProgramTab = .sota
    @State private var searchText = ""
    @State private var selectedItemId: String?

    enum ProgramTab: String, CaseIterable {
        case sota = "SOTA"
        case pota = "POTA"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Program", selection: $selectedTab) {
                ForEach(ProgramTab.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HStack(spacing: 0) {
                // Map
                mapView
                    .frame(minWidth: 300)

                Divider()

                // List + detail
                VStack(spacing: 0) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search \(selectedTab.rawValue)...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    // List
                    List(selection: $selectedItemId) {
                        switch selectedTab {
                        case .sota:
                            ForEach(filteredSummits, id: \.ref) { summit in
                                summitRow(summit)
                                    .tag(summit.ref)
                            }
                        case .pota:
                            ForEach(filteredParks, id: \.ref) { park in
                                parkRow(park)
                                    .tag(park.ref)
                            }
                        }
                    }
                    .listStyle(.inset)

                    // Detail footer
                    if let itemId = selectedItemId {
                        Divider()
                        detailView(for: itemId)
                    }
                }
                .frame(minWidth: 250, idealWidth: 350)
            }
        }
        .navigationTitle("SOTA / POTA")
    }

    // MARK: - Map

    private var mapView: some View {
        Map {
            switch selectedTab {
            case .sota:
                ForEach(sampleSummits, id: \.ref) { summit in
                    Marker(summit.name, systemImage: "mountain.2.fill",
                           coordinate: CLLocationCoordinate2D(
                            latitude: summit.lat, longitude: summit.lon))
                    .tint(.orange)
                }
            case .pota:
                ForEach(sampleParks, id: \.ref) { park in
                    Marker(park.name, systemImage: "tree.fill",
                           coordinate: CLLocationCoordinate2D(
                            latitude: park.lat, longitude: park.lon))
                    .tint(.green)
                }
            }
        }
    }

    // MARK: - Rows

    private func summitRow(_ summit: SampleSummit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(summit.ref)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(summit.points) pts")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            Text(summit.name)
                .font(.subheadline)
            HStack {
                Text("\(summit.altitude)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summit.region)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func parkRow(_ park: SamplePark) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(park.ref)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.green)
                Spacer()
            }
            Text(park.name)
                .font(.subheadline)
            Text(park.location)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    private func detailView(for itemId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if selectedTab == .sota, let summit = sampleSummits.first(where: { $0.ref == itemId }) {
                Text(summit.name).font(.headline)
                Text("Reference: \(summit.ref)").font(.caption)
                Text("Altitude: \(summit.altitude)m | Points: \(summit.points)").font(.caption)
                Text("Region: \(summit.region)").font(.caption).foregroundStyle(.secondary)
            } else if selectedTab == .pota, let park = sampleParks.first(where: { $0.ref == itemId }) {
                Text(park.name).font(.headline)
                Text("Reference: \(park.ref)").font(.caption)
                Text("Location: \(park.location)").font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Text("Activations: 0").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Log Activation") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Filtering

    private var filteredSummits: [SampleSummit] {
        if searchText.isEmpty { return sampleSummits }
        return sampleSummits.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.ref.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredParks: [SamplePark] {
        if searchText.isEmpty { return sampleParks }
        return sampleParks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.ref.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Sample Data

    struct SampleSummit {
        let ref: String
        let name: String
        let altitude: Int
        let points: Int
        let region: String
        let lat: Double
        let lon: Double
    }

    struct SamplePark {
        let ref: String
        let name: String
        let location: String
        let lat: Double
        let lon: Double
    }

    private var sampleSummits: [SampleSummit] {
        [
            SampleSummit(ref: "W1/CR-001", name: "Bear Mountain", altitude: 708, points: 6, region: "W1", lat: 41.312, lon: -73.988),
            SampleSummit(ref: "W1/CR-002", name: "Brace Mountain", altitude: 728, points: 6, region: "W1", lat: 42.047, lon: -73.506),
            SampleSummit(ref: "W2/GC-001", name: "Slide Mountain", altitude: 1274, points: 8, region: "W2", lat: 41.998, lon: -74.386),
            SampleSummit(ref: "W2/GC-002", name: "Hunter Mountain", altitude: 1281, points: 8, region: "W2", lat: 42.177, lon: -74.231),
            SampleSummit(ref: "W1/HA-001", name: "Mt. Greylock", altitude: 1064, points: 8, region: "W1", lat: 42.637, lon: -73.166),
            SampleSummit(ref: "W1/HA-005", name: "Mt. Everett", altitude: 791, points: 6, region: "W1", lat: 42.102, lon: -73.432),
        ]
    }

    private var sampleParks: [SamplePark] {
        [
            SamplePark(ref: "K-0001", name: "Acadia National Park", location: "Maine", lat: 44.338, lon: -68.273),
            SamplePark(ref: "K-0064", name: "Cape Cod National Seashore", location: "Massachusetts", lat: 41.870, lon: -69.971),
            SamplePark(ref: "K-0081", name: "Shenandoah National Park", location: "Virginia", lat: 38.483, lon: -78.451),
            SamplePark(ref: "K-0043", name: "Great Smoky Mountains NP", location: "Tennessee", lat: 35.611, lon: -83.489),
            SamplePark(ref: "K-4556", name: "Devil's Hopyard State Park", location: "Connecticut", lat: 41.478, lon: -72.342),
            SamplePark(ref: "K-4566", name: "Sleeping Giant State Park", location: "Connecticut", lat: 41.421, lon: -72.898),
        ]
    }
}

#Preview {
    SOTAPOTAView()
        .frame(width: 900, height: 600)
        .environment(AppState())
}
