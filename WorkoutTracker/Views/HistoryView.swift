import SwiftUI

/// View that displays exercise entries with timestamps
struct HistoryView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    private var sortedEntries: [ExerciseEntry] {
        viewModel.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(sortedEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.exerciseName)
                                .font(.headline)
                            Spacer()
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(entry.sets) { set in
                            Text("\(set.reps) reps" + (set.weight.map { " @ \($0)kg" } ?? ""))
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    let entriesToDelete = offsets.map { sortedEntries[$0] }
                    for entry in entriesToDelete {
                        if let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.entries.remove(at: index)
                        }
                    }
                    viewModel.save()
                }
            }
            #if canImport(UIKit)
            .listStyle(InsetGroupedListStyle())
            #else
            .listStyle(PlainListStyle())
            #endif
            .navigationTitle("History")
        }
    }
}
