import SwiftUI

struct MarkdownViewer: View {
    var fileURL: URL

    var body: some View {
        ScrollView {
            VStack {
                Text(try! String(contentsOf: fileURL))
                    .padding()
            }
        }
    }
}
