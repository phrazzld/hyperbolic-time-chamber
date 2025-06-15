import SwiftUI

/// Temporary input model for capturing table sets
struct SetInput: Identifiable {
    let id = UUID()
    var reps: String = ""
    var weight: String = ""
}

/// View for adding a new exercise entry with multiple sets
struct AddEntryView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Binding var isPresented: Bool

    @State private var exerciseName = ""
    @State private var sets: [SetInput] = [SetInput()]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise")) {
                    TextField("Name", text: $exerciseName)
                }
                Section(header: Text("Sets")) {
                    ForEach($sets) { $set in
                        HStack {
                        TextField("Reps", text: $set.reps)
#if canImport(UIKit)
                                .keyboardType(.numberPad)
#endif
                                .frame(maxWidth: .infinity)
                            TextField("Weight (optional)", text: $set.weight)
#if canImport(UIKit)
                                .keyboardType(.decimalPad)
#endif
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Button(action: {
                        sets.append(SetInput())
                    }, label: {
                        Label("Add Set", systemImage: "plus")
                    })
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let inputSets = sets.compactMap { input -> ExerciseSet? in
                            guard let reps = Int(input.reps.trimmingCharacters(in: .whitespaces)),
                                  reps > 0 else { return nil }
                            let weight = Double(input.weight.trimmingCharacters(in: .whitespaces))
                            return ExerciseSet(reps: reps, weight: weight)
                        }
                        guard !inputSets.isEmpty,
                              !exerciseName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let entry = ExerciseEntry(
                            exerciseName: exerciseName.trimmingCharacters(in: .whitespaces),
                            date: Date(),
                            sets: inputSets
                        )
                        viewModel.addEntry(entry)
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
