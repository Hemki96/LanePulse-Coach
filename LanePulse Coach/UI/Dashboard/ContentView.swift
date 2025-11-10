import SwiftUI

struct ContentView: View {
    @State private var text = ""
    @State private var isValid = false

    var body: some View {
        VStack {
            TextField("Enter text", text: $text)
                .padding()
                .onChange(of: text) { newValue in
                    isValid = newValue.count > 3
                }

            if isValid {
                Text("Valid input!")
            }
        }
        .padding()
        .onChange(of: isValid) { newValue in
            print("Validation changed to \(newValue)")
        }
    }
}
