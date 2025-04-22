import SwiftUI

struct ContentView: View {
    @State private var mood: String = "Chill"
    @State private var notes: String = ""
    @State private var song: String = ""
    @State private var timeRemaining: Int? = nil
    @State private var timer: Timer? = nil
    @State private var isTimerRunning = false
    @State private var timerMinutes: Int? = nil
    @State private var colorScheme: ColorScheme = .light // Start with light mode
    @State private var placeholderText: String = "Begin writing your thoughts..." // Placeholder

    let moods = ["Chill", "Focused", "Reflective", "Angsty", "Joyful"]
    let timerOptions: [Int?] = [nil, 15, 30, 60] // Nil for off, then minutes

    var body: some View {
        ZStack(alignment: .bottom) { // ZStack to overlay bottom controls
            Group {
                if colorScheme == .light {
                    Color("Cream")
                } else {
                    Color(.black)
                }
            }
            .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading) {
                // Song Entry Section
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

                // Mood-Based Suggestions (Static for now)
                if !moodBasedSuggestions(for: mood).isEmpty {
                    Text("Suggestions for '\(mood)' mood:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.leading, 10)

                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(moodBasedSuggestions(for: mood), id: \.self) { suggestion in
                                Text(suggestion)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(colorScheme == .light ? .black : .white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.leading, 10)
                    }
                    .padding(.bottom, 15)
                }

                // Main Writing Area
                TextEditor(text: $notes)
                    .font(fontForMood(mood))
                    .padding()
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(colorScheme == .light ? .black : .white)
                    .overlay(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text(placeholderText)
                                .foregroundColor(.gray.opacity(0.7))
                                .padding()
                        }
                    }
            }
            .padding(.bottom, 60) // Make space for the bottom controls

            // Bottom Navigation Bar
            HStack {
                // Mood Control
                Button(action: {
                    if let currentIndex = moods.firstIndex(of: mood) {
                        let nextIndex = (currentIndex + 1) % moods.count
                        mood = moods[nextIndex]
                    }
                }) {
                    Text(mood)
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .padding(.horizontal)
                }

                Spacer()

                // Timer Control
                Button(action: {
                    if let current = timerMinutes, let currentIndex = timerOptions.firstIndex(of: current) {
                        let nextIndex = (currentIndex + 1) % timerOptions.count
                        timerMinutes = timerOptions[nextIndex]
                    } else {
                        if let firstDuration = timerOptions.compactMap({ $0 }).first {
                            timerMinutes = firstDuration
                        } else {
                            timerMinutes = nil
                        }
                    }

                    timeRemaining = timerMinutes.map { $0 * 60 }
                    timer?.invalidate()
                    isTimerRunning = false

                    if let minutes = timerMinutes {
                        startTimer(minutes: minutes)
                    }
                }) {
                    Text(timerMinutes == nil ? "Timer" : "\(timerMinutes!) min")
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .padding(.horizontal)
                }

                // Timer Display
                if let time = timeRemaining {
                    Text("⏱ \(formatTime(time))")
                        .font(.caption)
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .padding(.leading)
                }

                Spacer()

                // Theme Toggle
                Button(action: {
                    colorScheme = colorScheme == .light ? .dark : .light
                }) {
                    Image(systemName: colorScheme == .light ? "sun.max.fill" : "moon.fill")
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .padding(.horizontal)
                }

                // Save Button at the far right
                Button(action: {
                    saveEntry()
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding([.top, .bottom], 10)
                        .padding([.leading, .trailing], 20)
                        .background(Color.blue.opacity(0.8)) // Keep the color scheme consistent
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5) // Soft shadow for depth
                }
                .padding(.horizontal) // Ensures it stays to the far right of the bottom bar
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(colorScheme == .light ? Color("Cream").opacity(0.8) : Color(.black).opacity(0.8)) // Semi-transparent background
        }
    }

    // Timer Logic
    func startTimer(minutes: Int) {
        timeRemaining = minutes * 60
        isTimerRunning = true
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let time = timeRemaining, time > 0 {
                timeRemaining! -= 1
            } else {
                timer?.invalidate()
                isTimerRunning = false
            }
        }
    }

    func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Mood Styling
    func fontForMood(_ mood: String) -> Font {
        switch mood {
        case "Chill":
            return .custom("Georgia", size: 18)
        case "Focused":
            return .system(size: 18, weight: .medium, design: .monospaced)
        case "Reflective":
            return .custom("Palatino", size: 18)
        case "Angsty":
            return .system(size: 18, weight: .bold)
        case "Joyful":
            return .custom("Snell Roundhand", size: 18)
        default:
            return .body
        }
    }

    // Save Entry
    func saveEntry() {
        let journalContent = """
        Mood: \(mood)
        Song: \(song)
        Notes:
        \(notes)
        """

        // Path to save the file (you can customize this part as needed)
        let fileManager = FileManager.default
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirectory.appendingPathComponent("Journal-\(UUID().uuidString).txt")

        do {
            try journalContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Journal saved to \(fileURL.path)")
        } catch {
            print("Error saving journal: \(error.localizedDescription)")
        }
    }

    // Mood-Based Suggestions
    func moodBasedSuggestions(for mood: String) -> [String] {
        switch mood {
        case "Chill":
            return ["Lo-fi Hip Hop", "Ambient Electronic", "Acoustic Covers", "Soft Piano"]
        case "Focused":
            return ["Instrumental Study Music", "Classical Music", "Ambient Sounds", "Minimal Techno"]
        case "Reflective":
            return ["Indie Folk", "Atmospheric Rock", "Acoustic Ballads", "Post-Rock"]
        case "Angsty":
            return ["Alternative Rock", "Emo", "Grunge", "Heavy Melodic"]
        case "Joyful":
            return ["Upbeat Pop", "Indie Pop", "Funk", "Soul"]
        default:
            return []
        }
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
    }
}
