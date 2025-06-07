import SwiftUI

/// View that displays exercise entries grouped by day
struct HistoryView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    private var groupedEntries: [Date: [ExerciseEntry]] {
        Dictionary(grouping: viewModel.entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
    }

    private var sortedDates: [Date] {
        groupedEntries.keys.sorted(by: >)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(sortedDates, id: \.self) { date in
                    Section(header: Text(date, style: .date)) {
                        ForEach(groupedEntries[date]!) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.exerciseName)
                                    .font(.headline)
                                ForEach(entry.sets) { set in
                                    Text("\(set.reps) reps" + (set.weight != nil ? " @ \(set.weight!)kg" : ""))
                                        .font(.subheadline)
                                }
                            }
                        }
                        .onDelete { offsets in
                            var global = viewModel.entries
                            let entriesForDate = groupedEntries[date]!
                            for index in offsets {
                                if let idx = global.firstIndex(where: { $0.id == entriesForDate[index].id }) {
                                    global.remove(at: idx)
                                }
                            }
                            viewModel.entries = global
                            viewModel.save()
                        }
                    }
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