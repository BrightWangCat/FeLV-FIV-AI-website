import SwiftUI

/// Reusable form section for entering optional patient metadata.
struct PatientInfoFormView: View {
    @Binding var shareInfo: Bool
    @Binding var species: String
    @Binding var age: String
    @Binding var sex: String
    @Binding var breed: String
    @Binding var zipCode: String

    private let sexOptions = [
        ("", "Not specified"),
        ("M", "Male"),
        ("F", "Female"),
        ("CM", "Castrated Male"),
        ("SF", "Spayed Female"),
    ]

    var body: some View {
        Section("Patient Information") {
            Toggle("Share patient info", isOn: $shareInfo)

            if shareInfo {
                TextField("Species", text: $species)
                    .textContentType(.none)

                TextField("Age (years)", text: $age)
                    .keyboardType(.numberPad)

                Picker("Sex", selection: $sex) {
                    ForEach(sexOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }

                TextField("Breed", text: $breed)
                    .textContentType(.none)

                TextField("Zip Code", text: $zipCode)
                    .keyboardType(.numberPad)
                    .textContentType(.postalCode)
            }
        }
    }
}
