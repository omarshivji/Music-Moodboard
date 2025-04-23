import SwiftUI

struct ContentView: View {
    @State private var mood: String = "Chill"
    @State private var notes: String = ""
    @State private var song: String = ""
    @State private var timeRemaining: Int? = nil
    @State private var timer: Timer? = nil
    @State private var timerMinutes: Int? = nil
    @State private var colorScheme: ColorScheme = .light
    @State private var placeholderText: String = "Begin writing your thoughts..."
    @State private var showSavedMessage = false
    @State private var fileList: [URL] = []
    @State private var selectedFile: URL?
    @State private var showingFile = false

    let moods = ["Chill", "Focused", "Reflective", "Angsty", "Joyful"]
    let timerOptions: [Int?] = [nil, 15, 30, 60]

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                (colorScheme == .light ? Color("Cream") : Color.black)
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading) {

                        // 🎵 Currently Listening To
                        VStack(alignment: .leading) {
                            Text("Currently Listening To:")
                                .font(.headline)
                                .foregroundColor(colorScheme == .light ? .black : .white)
                                .padding(.leading, 10)
                                .padding(.top, 10)

                            TextField("Enter song name...", text: $song)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.title3)
                                .foregroundColor(colorScheme == .light ? .black : .white)
                                .padding([.leading, .trailing], 10)
                        }
                        .padding(.bottom, 15)

                        // 🌈 Mood Suggestions
                        if !moodBasedSuggestions(for: mood).isEmpty {
                            Text("Suggestions for '\(mood)' mood:")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .light ? .black : .white)
                                .padding(.leading, 10)

                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(moodBasedSuggestions(for: mood), id: \.self) { suggestion in
                                        Text(suggestion)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                            .foregroundColor(colorScheme == .light ? .black : .white)
                                    }
                                }
                                .padding(.leading, 10)
                            }
                            .padding(.bottom, 15)
                        }

                        // ✍️ Notes
                        TextEditor(text: $notes)
                            .font(fontForMood(mood))
                            .padding()
                            .frame(minHeight: 200, maxHeight: .infinity)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(colorScheme == .light ? .black : .white)
                            .overlay(alignment: .topLeading) {
                                if notes.isEmpty {
                                    Text(placeholderText)
                                        .foregroundColor(colorScheme == .light ? .gray.opacity(0.7) : .white.opacity(0.7))
                                        .padding()
                                }
                            }

                        Divider().padding(.vertical)

                        Text("Previous Entries")
                            .font(.headline)
                            .foregroundColor(colorScheme == .light ? .black : .white)
                            .padding(.horizontal)

                        // Friendly-named entries
                        let sortedFiles = fileList.sorted { $0.lastPathComponent > $1.lastPathComponent }
                        ForEach(Array(sortedFiles.enumerated()), id: \.element) { index, file in
                            Button(action: {
                                selectedFile = file
                                showingFile = true
                            }) {
                                HStack {
                                    Text("Entry \(index + 1) – \(displayDate(for: file))")
                                        .font(.subheadline)
                                        .foregroundColor(colorScheme == .light ? .black : .white)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(fileTimeString(file))
                                        .font(.caption)
                                        .foregroundColor(colorScheme == .light ? .black.opacity(0.6) : .white.opacity(0.6))
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.bottom, 70)
                }

                // 🔽 Bottom Bar
                HStack {
                    Button(action: cycleMood) {
                        Text(mood)
                            .foregroundColor(colorScheme == .light ? .black : .white)
                            .padding(.horizontal)
                    }

                    Spacer()

                    Button(action: cycleTimer) {
                        Text(timerMinutes == nil ? "Timer" : "\(timerMinutes!) min")
                            .foregroundColor(colorScheme == .light ? .black : .white)
                            .padding(.horizontal)
                    }

                    if let time = timeRemaining {
                        Text("⏱ \(formatTime(time))")
                            .font(.caption)
                            .foregroundColor(colorScheme == .light ? .black : .white)
                            .padding(.leading)
                    }

                    Spacer()

                    Button(action: {
                        colorScheme = (colorScheme == .light) ? .dark : .light
                    }) {
                        Image(systemName: colorScheme == .light ? "sun.max.fill" : "moon.fill")
                            .foregroundColor(colorScheme == .light ? .black : .white)
                            .padding(.horizontal)
                    }

                    Button(action: saveEntryToFile) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(colorScheme == .light ? .black : .white)  // Adjust text color based on colorScheme
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background((colorScheme == .light ? Color("Cream") : Color.black).opacity(0.8))
            }

            // ✅ Saved Message
            if showSavedMessage {
                Text("Entry Saved")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("Cream"))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.opacity)
            }
        }
        .onAppear(perform: loadSavedFiles)
        .sheet(isPresented: $showingFile) {
            if let selectedFile = selectedFile {
                MarkdownViewer(fileURL: selectedFile)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSavedMessage)
        .preferredColorScheme(colorScheme)
    }

    // MARK: - File Management

    private func saveEntryToFile() {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = docsURL.appendingPathComponent("MusicMoodboard")
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let ts = df.string(from: Date())
        let uuid = UUID().uuidString
        let filename = "[\(uuid)]-[\(ts)].md"
        let fileURL = folderURL.appendingPathComponent(filename)

        let md = """
        # \(mood)
        **Song:** \(song)

        \(notes)
        """

        do {
            try md.write(to: fileURL, atomically: true, encoding: .utf8)
            showSavedMessage = true
            DispatchQueue.main.asyncAfter(deadline: .now()+1.5) {
                showSavedMessage = false
            }
            loadSavedFiles()
        } catch {
            print("❌ Write error:", error)
        }
    }

    private func loadSavedFiles() {
        let fm = FileManager.default
        let folder = fm
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MusicMoodboard")
        do {
            let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            fileList = files.filter { $0.pathExtension == "md" }
        } catch {
            print("❌ Could not read folder:", error)
        }
    }

    // MARK: - Helpers

    private func displayDate(for file: URL) -> String {
        let creation = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy.MM.dd"
        return df.string(from: creation)
    }

    private func fileTimeString(_ file: URL) -> String {
        let creation = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        return tf.string(from: creation)
    }

    private func cycleMood() {
        if let idx = moods.firstIndex(of: mood) {
            mood = moods[(idx + 1) % moods.count]
        }
    }

    private func cycleTimer() {
        if let cur = timerMinutes, let idx = timerOptions.firstIndex(of: cur) {
            timerMinutes = timerOptions[(idx + 1) % timerOptions.count]
        } else {
            timerMinutes = timerOptions.compactMap { $0 }.first
        }
        timeRemaining = timerMinutes.map { $0 * 60 }
        timer?.invalidate()
        if let m = timerMinutes { startTimer(minutes: m) }
    }

    private func startTimer(minutes: Int) {
        timeRemaining = minutes * 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let t = timeRemaining, t > 0 else {
                timer?.invalidate()
                return
            }
            timeRemaining! -= 1
        }
    }

    private func formatTime(_ total: Int) -> String {
        String(format: "%02d:%02d", total/60, total%60)
    }

    private func moodBasedSuggestions(for mood: String) -> [String] {
        switch mood {
        case "Chill":      return ["Lo-fi Hip Hop", "Ambient Electronic", "Acoustic Covers", "Soft Piano"]
        case "Focused":    return ["Instrumental Beats", "Concentration Music", "Deep House"]
        case "Reflective": return ["Indie Rock", "Jazz", "Blues", "Soul"]
        case "Angsty":     return ["Alternative Rock", "Punk", "Grunge"]
        case "Joyful":     return ["Pop", "Dance", "Funk", "Disco"]
        default:           return []
        }
    }

    private func fontForMood(_ mood: String) -> Font {
        switch mood {
        case "Chill":      return .custom("Georgia", size: 18)
        case "Focused":    return .system(size: 18, weight: .medium, design: .monospaced)
        case "Reflective": return .custom("Palatino", size: 18)
        case "Angsty":     return .system(size: 18, weight: .bold)
        case "Joyful":     return .custom("Snell Roundhand", size: 18)
        default:           return .body
        }
    }
}

struct MarkdownViewer: View {
    let fileURL: URL
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            Text((try? String(contentsOf: fileURL)) ?? "Could not load content.")
                .foregroundColor(colorScheme == .light ? .black : .white)
                .padding()
        }
        .onAppear {
            if let window = NSApplication.shared.windows.first {
                window.title = fileURL.lastPathComponent
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
    }
}
