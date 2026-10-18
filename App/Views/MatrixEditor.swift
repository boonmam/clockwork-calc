import SwiftUI

struct MatrixEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rows = 2
    @State private var columns = 2
    @State private var cells = Array(repeating: Array(repeating: "0", count: 8), count: 8)
    let insert: (String) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Dimensions") {
                    Stepper("Rows: \(rows)", value: $rows, in: 1...8)
                    Stepper("Columns: \(columns)", value: $columns, in: 1...8)
                }
                Section("Entries") {
                    Text("Enter numbers, fractions, or symbols. Swipe horizontally for larger matrices.").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal) {
                        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(0..<rows, id: \.self) { row in
                                GridRow {
                                    ForEach(0..<columns, id: \.self) { column in
                                        TextField("0", text: $cells[row][column])
                                            .font(.system(.body, design: .monospaced)).textFieldStyle(.roundedBorder)
                                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                                            .frame(width: 85).accessibilityLabel("Row \(row+1), column \(column+1)")
                                    }
                                }
                            }
                        }.padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Insert matrix")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        let rowText = (0..<rows).map { row in
                            "[" + (0..<columns).map { column in
                                let value = cells[row][column].trimmingCharacters(in: .whitespacesAndNewlines)
                                return value.isEmpty ? "0" : "(" + value + ")"
                            }.joined(separator: ",") + "]"
                        }
                        insert("matrix(" + rowText.joined(separator: ",") + ")"); dismiss()
                    }.accessibilityIdentifier("insertMatrix")
                }
            }
        }
    }
}
