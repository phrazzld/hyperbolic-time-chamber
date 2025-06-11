import SwiftUI

/// Main tab view for switching between History, Add Entry, and Export
///
/// Provides the primary navigation interface with three tabs:
/// - History: Browse past workout entries
/// - Add Entry: Create new exercise entries
/// - Export: Share workout data as JSON
///
/// Uses modal sheets for add and export functionality to maintain focus
/// and provide clear entry/exit paths for user interactions.
struct ContentView: View {
    /// Shared workout data and operations injected via environment
    @EnvironmentObject var viewModel: WorkoutViewModel

    /// Controls visibility of the Add Entry modal sheet
    @State private var showAddEntry = false

    /// Controls visibility of the Export/Share modal sheet  
    @State private var showExporter = false

    var body: some View {
        TabView {
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            Button(action: { showAddEntry = true }, label: {
                Label("Add Entry", systemImage: "plus.circle")
            })
            .tabItem {
                Label("Add", systemImage: "plus")
            }
            Button(action: { showExporter = true }, label: {
                Label("Export", systemImage: "square.and.arrow.up")
            })
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showAddEntry) {
            AddEntryView(isPresented: $showAddEntry)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showExporter) {
            if let url = viewModel.exportJSON() {
                // Platform-conditional export: iOS devices get native share sheet,
                // other platforms (macOS, watchOS) show fallback message since
                // UIActivityViewController is iOS-specific
#if canImport(UIKit)
                ActivityView(activityItems: [url])
#else
                Text("Export functionality requires iOS")
                    .padding()
#endif
            } else {
                Text("No data to export")
                    .padding()
            }
        }
    }
}
