// EmCommView.swift — Emergency Communications tools view
// ICS Forms, Net Logger, and Winlink placeholder.

import SwiftUI
import UniformTypeIdentifiers

struct EmCommView: View {
    @State private var selectedTab: EmCommTab = .icsForms

    enum EmCommTab: String, CaseIterable {
        case icsForms = "ICS Forms"
        case netLogger = "Net Logger"
        case winlink = "Winlink"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                ForEach(EmCommTab.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch selectedTab {
            case .icsForms:
                ICSFormsListView()
            case .netLogger:
                NetLoggerView()
            case .winlink:
                WinlinkPlaceholderView()
            }
        }
        .navigationTitle("Emergency Communications")
    }
}

// MARK: - ICS Forms List

private struct ICSFormsListView: View {
    @State private var forms = ICSFormsListView.sampleForms
    @State private var selectedFormId: UUID?
    @State private var showingNewFormSheet = false

    var body: some View {
        HStack(spacing: 0) {
            // Form list
            VStack(spacing: 0) {
                HStack {
                    Text("Forms")
                        .font(.headline)
                    Spacer()
                    Menu {
                        Button("ICS-213 General Message") {
                            addForm(type: "ICS-213")
                        }
                        Button("ICS-214 Activity Log") {
                            addForm(type: "ICS-214")
                        }
                        Button("ICS-309 Communications Log") {
                            addForm(type: "ICS-309")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                List(forms, selection: $selectedFormId) { form in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(form.formType)
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(formTypeColor(form.formType))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                            Text(form.incidentName)
                                .font(.subheadline.bold())
                        }
                        Text(form.preparedBy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(form.date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .tag(form.id)
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)

            Divider()

            // Form detail
            if let formId = selectedFormId,
               let form = forms.first(where: { $0.id == formId }) {
                ICSFormDetailView(form: form)
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a form")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func addForm(type: String) {
        let form = SampleForm(
            formType: type,
            incidentName: "New Incident",
            preparedBy: "Operator",
            date: "2026-03-19"
        )
        forms.insert(form, at: 0)
        selectedFormId = form.id
    }

    private func formTypeColor(_ type: String) -> Color {
        switch type {
        case "ICS-213": return .blue
        case "ICS-214": return .green
        case "ICS-309": return .orange
        default: return .gray
        }
    }

    // MARK: - Sample Data

    struct SampleForm: Identifiable {
        let id = UUID()
        var formType: String
        var incidentName: String
        var preparedBy: String
        var date: String
    }

    static let sampleForms: [SampleForm] = [
        SampleForm(formType: "ICS-213", incidentName: "Winter Storm Alpha", preparedBy: "N1ABC", date: "2026-03-18"),
        SampleForm(formType: "ICS-309", incidentName: "Winter Storm Alpha", preparedBy: "W2DEF", date: "2026-03-18"),
        SampleForm(formType: "ICS-214", incidentName: "County Exercise 2026", preparedBy: "K3GHI", date: "2026-03-15"),
        SampleForm(formType: "ICS-213", incidentName: "County Exercise 2026", preparedBy: "N1ABC", date: "2026-03-15"),
    ]
}

// MARK: - ICS Form Detail

private struct ICSFormDetailView: View {
    let form: ICSFormsListView.SampleForm
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(form.formType)
                        .font(.title2.bold())
                    Spacer()
                    Button("Export PDF") {
                        exportToPDF()
                    }
                    .buttonStyle(.bordered)
                }

                if let error = exportError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                Group {
                    formField(label: "Incident Name", value: form.incidentName)
                    formField(label: "Prepared By", value: form.preparedBy)
                    formField(label: "Date", value: form.date)
                }

                if form.formType == "ICS-213" {
                    Divider()
                    formField(label: "To", value: "EOC Director")
                    formField(label: "From", value: form.preparedBy)
                    formField(label: "Subject", value: "Status Update")
                    Text("Message")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextEditor(text: .constant("All stations checked in. No emergency traffic. Net control is \(form.preparedBy)."))
                        .frame(minHeight: 100)
                        .font(.body)
                        .border(Color(nsColor: .separatorColor))
                }

                if form.formType == "ICS-309" {
                    Divider()
                    formField(label: "Net Name", value: "County ARES Net")
                    formField(label: "Frequency", value: "146.760 MHz")
                    Text("Communications Log")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    commLogTable
                }

                Spacer()
            }
            .padding()
        }
    }

    private func formField(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .font(.body)
            Spacer()
        }
    }

    private var commLogTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Time").font(.caption.bold()).frame(width: 60, alignment: .leading)
                Text("Station").font(.caption.bold()).frame(width: 80, alignment: .leading)
                Text("Message").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ForEach(sampleLogEntries, id: \.time) { entry in
                HStack {
                    Text(entry.time).font(.system(.caption, design: .monospaced)).frame(width: 60, alignment: .leading)
                    Text(entry.station).font(.system(.caption, design: .monospaced).bold()).frame(width: 80, alignment: .leading)
                    Text(entry.message).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                Divider().padding(.leading, 8)
            }
        }
        .border(Color(nsColor: .separatorColor))
    }

    private var sampleLogEntries: [(time: String, station: String, message: String)] {
        [
            (time: "19:00", station: "N1ABC", message: "Net opened on 146.760"),
            (time: "19:02", station: "W2DEF", message: "Checked in, no traffic"),
            (time: "19:03", station: "K3GHI", message: "Checked in, routine traffic"),
            (time: "19:05", station: "WA4JKL", message: "Checked in, priority traffic"),
            (time: "19:08", station: "N1ABC", message: "Net secured"),
        ]
    }

    // MARK: - PDF Export

    private func exportToPDF() {
        let panel = NSSavePanel()
        panel.title = "Export \(form.formType)"
        panel.nameFieldStringValue = "\(form.formType)_\(form.date).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            exportError = "Failed to create PDF context"
            return
        }

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        context.beginPage(mediaBox: &mediaBox)

        let textWidth = pageWidth - margin * 2
        var yPos = pageHeight - margin

        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
        let title = "\(form.formType) — \(form.incidentName)" as NSString
        title.draw(at: CGPoint(x: margin, y: yPos - 20), withAttributes: titleAttrs)
        yPos -= 40

        // Fields
        let labelFont = NSFont.boldSystemFont(ofSize: 10)
        let valueFont = NSFont.systemFont(ofSize: 12)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: NSColor.secondaryLabelColor]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont]

        func drawField(_ label: String, _ value: String) {
            (label as NSString).draw(at: CGPoint(x: margin, y: yPos - 12), withAttributes: labelAttrs)
            (value as NSString).draw(at: CGPoint(x: margin + 130, y: yPos - 14), withAttributes: valueAttrs)
            yPos -= 22
        }

        drawField("Incident Name:", form.incidentName)
        drawField("Prepared By:", form.preparedBy)
        drawField("Date:", form.date)

        if form.formType == "ICS-213" {
            yPos -= 10
            // Line
            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.move(to: CGPoint(x: margin, y: yPos))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
            context.strokePath()
            yPos -= 15

            drawField("To:", "EOC Director")
            drawField("From:", form.preparedBy)
            drawField("Subject:", "Status Update")

            yPos -= 10
            ("Message:" as NSString).draw(at: CGPoint(x: margin, y: yPos - 12), withAttributes: labelAttrs)
            yPos -= 22

            let messageText = "All stations checked in. No emergency traffic. Net control is \(form.preparedBy)."
            let messageAttrs: [NSAttributedString.Key: Any] = [.font: valueFont]
            let messageRect = CGRect(x: margin, y: yPos - 100, width: textWidth, height: 100)
            (messageText as NSString).draw(in: messageRect, withAttributes: messageAttrs)
        }

        if form.formType == "ICS-309" {
            yPos -= 10
            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.move(to: CGPoint(x: margin, y: yPos))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
            context.strokePath()
            yPos -= 15

            drawField("Net Name:", "County ARES Net")
            drawField("Frequency:", "146.760 MHz")
            yPos -= 10

            // Table header
            let headerFont = NSFont.boldSystemFont(ofSize: 9)
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont]
            let cellFont = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            let cellAttrs: [NSAttributedString.Key: Any] = [.font: cellFont]

            ("Time" as NSString).draw(at: CGPoint(x: margin, y: yPos - 12), withAttributes: headerAttrs)
            ("Station" as NSString).draw(at: CGPoint(x: margin + 60, y: yPos - 12), withAttributes: headerAttrs)
            ("Message" as NSString).draw(at: CGPoint(x: margin + 150, y: yPos - 12), withAttributes: headerAttrs)
            yPos -= 18

            for entry in sampleLogEntries {
                (entry.time as NSString).draw(at: CGPoint(x: margin, y: yPos - 12), withAttributes: cellAttrs)
                (entry.station as NSString).draw(at: CGPoint(x: margin + 60, y: yPos - 12), withAttributes: cellAttrs)
                (entry.message as NSString).draw(at: CGPoint(x: margin + 150, y: yPos - 12), withAttributes: cellAttrs)
                yPos -= 16
            }
        }

        // Footer
        let footerFont = NSFont.systemFont(ofSize: 8)
        let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: NSColor.tertiaryLabelColor]
        let footer = "Generated by HamStation Pro — \(Date().formatted())" as NSString
        footer.draw(at: CGPoint(x: margin, y: margin - 20), withAttributes: footerAttrs)

        context.endPage()
        context.closePDF()

        exportError = nil
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Net Logger View

private struct NetLoggerView: View {
    @State private var isNetActive = true
    @State private var newCallsign = ""
    @State private var newTraffic = "None"

    private let trafficTypes = ["None", "Routine", "Priority", "Emergency"]

    var body: some View {
        VStack(spacing: 0) {
            // Net info header
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("County ARES Net")
                        .font(.headline)
                    Text("146.760 MHz FM")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NCS: N1ABC")
                        .font(.subheadline)
                    Text("Started: 19:00 UTC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(isNetActive ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(isNetActive ? "Active" : "Closed")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isNetActive ? Color.green : Color.red).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button(isNetActive ? "End Net" : "Start Net") {
                    isNetActive.toggle()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Quick check-in
            HStack(spacing: 8) {
                TextField("Callsign", text: $newCallsign)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Picker("Traffic", selection: $newTraffic) {
                    ForEach(trafficTypes, id: \.self) { Text($0) }
                }
                .frame(width: 120)
                Button("Check In") {
                    newCallsign = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newCallsign.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Check-in list
            List {
                ForEach(Self.sampleCheckIns, id: \.callsign) { checkIn in
                    HStack {
                        Text(checkIn.time)
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 50)
                        Text(checkIn.callsign)
                            .font(.system(.body, design: .monospaced).bold())
                            .frame(width: 80, alignment: .leading)
                        Text(checkIn.name)
                            .frame(width: 100, alignment: .leading)
                        trafficBadge(checkIn.traffic)
                        Text(checkIn.remarks)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func trafficBadge(_ traffic: String) -> some View {
        Text(traffic)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(trafficColor(traffic).opacity(0.15))
            .foregroundStyle(trafficColor(traffic))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .frame(width: 80)
    }

    private func trafficColor(_ traffic: String) -> Color {
        switch traffic.lowercased() {
        case "emergency": return .red
        case "priority": return .orange
        case "routine": return .blue
        default: return .gray
        }
    }

    struct SampleCheckIn {
        let time: String
        let callsign: String
        let name: String
        let traffic: String
        let remarks: String
    }

    static let sampleCheckIns: [SampleCheckIn] = [
        SampleCheckIn(time: "19:02", callsign: "W2DEF", name: "John", traffic: "None", remarks: ""),
        SampleCheckIn(time: "19:03", callsign: "K3GHI", name: "Mary", traffic: "Routine", remarks: "Welfare message for EOC"),
        SampleCheckIn(time: "19:04", callsign: "WA4JKL", name: "Bob", traffic: "Priority", remarks: "Road closure on Rt 9"),
        SampleCheckIn(time: "19:05", callsign: "N5MNO", name: "Alice", traffic: "None", remarks: ""),
        SampleCheckIn(time: "19:06", callsign: "KB6PQR", name: "Tom", traffic: "Emergency", remarks: "Medical emergency at shelter"),
        SampleCheckIn(time: "19:08", callsign: "WB7STU", name: "Sara", traffic: "None", remarks: ""),
    ]
}

// MARK: - Winlink Placeholder

private struct WinlinkPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Winlink Integration")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Winlink email over radio support is planned for a future release.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmCommView()
        .frame(width: 900, height: 600)
        .environment(AppState())
}
