import SwiftUI

/// Main tab view for switching between History, Add Entry, and Export
struct ContentView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @State private var showAddEntry = false
    @State private var showExporter = false

    var body: some View {
        TabView {
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            Button(action: { showAddEntry = true }) {
                Label("Add Entry", systemImage: "plus.circle")
            }
            .tabItem {
                Label("Add", systemImage: "plus")
            }
            Button(action: { showExporter = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
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
#if canImport(UIKit)
                ActivityView(activityItems: [url])
#else
                Text("No data to export")
                    .padding()
#endif
            } else {
                Text("No data to export")
                    .padding()
            }
        }
    }
}