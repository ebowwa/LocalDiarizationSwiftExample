//
//  ContentView.swift
//  LocalDiarizationTest
//
//  Created by Elijah Arbee on 8/20/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var recordingManager = AudioRecordingManager()
    @StateObject private var fileManager = AudioFileManager()
    @StateObject private var diarizationManager = DiarizationManager()
    @State private var showingPermissionAlert = false
    @State private var permissionDenied = false
    @State private var showingFilePicker = false
    @State private var selectedTab = 0 // 0 = Record, 1 = Upload
    
    // Computed property to get current audio samples
    var currentAudioSamples: [Float] {
        selectedTab == 0 ? recordingManager.audioSamples : fileManager.audioSamples
    }
    
    var hasAudioToProcess: Bool {
        selectedTab == 0 ? recordingManager.hasRecording : fileManager.hasAudio
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HeaderView()
                
                // Audio Source Selector
                AudioSourceSelector(selectedTab: $selectedTab)
                
                // Show appropriate controls based on selected tab
                if selectedTab == 0 {
                    RecordingSection(
                        recordingManager: recordingManager,
                        diarizationManager: diarizationManager,
                        showingPermissionAlert: $showingPermissionAlert,
                        permissionDenied: $permissionDenied,
                        audioSamples: currentAudioSamples
                    )
                } else {
                    UploadSection(
                        fileManager: fileManager,
                        diarizationManager: diarizationManager,
                        showingFilePicker: $showingFilePicker,
                        audioSamples: currentAudioSamples
                    )
                }
                
                // Common processing view
                if diarizationManager.isProcessing {
                    ProcessingView(
                        progress: diarizationManager.processingProgress,
                        statusMessage: diarizationManager.statusMessage
                    )
                }
                
                // Results view
                if !diarizationManager.segments.isEmpty {
                    SegmentsView(
                        segments: diarizationManager.segments,
                        statistics: diarizationManager.getSpeakerStatistics()
                    )
                }
                
                if let error = diarizationManager.error {
                    ErrorView(error: error)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Speaker Diarization")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("OK") {
                if permissionDenied {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            }
        } message: {
            Text(permissionDenied ? 
                 "Please enable microphone access in Settings to use this feature." :
                 "This app needs microphone access to record audio for speaker diarization.")
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: AudioFileManager.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    Task {
                        await fileManager.processAudioFile(url: file)
                    }
                }
            case .failure(let error):
                fileManager.error = "Failed to import file: \(error.localizedDescription)"
            }
        }
    }
}

struct AudioSourceSelector: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        Picker("Audio Source", selection: $selectedTab) {
            Label("Record", systemImage: "mic.fill").tag(0)
            Label("Upload", systemImage: "doc.fill").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

struct RecordingSection: View {
    @ObservedObject var recordingManager: AudioRecordingManager
    @ObservedObject var diarizationManager: DiarizationManager
    @Binding var showingPermissionAlert: Bool
    @Binding var permissionDenied: Bool
    let audioSamples: [Float]
    
    var body: some View {
        VStack(spacing: 20) {
            // Recording controls
            HStack(spacing: 20) {
                // Record/Stop button
                Button(action: toggleRecording) {
                    VStack(spacing: 8) {
                        Image(systemName: recordingManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(recordingManager.isRecording ? .red : .blue)
                            .symbolEffect(.bounce, value: recordingManager.isRecording)
                        
                        Text(recordingManager.isRecording ? "Stop" : "Record")
                            .font(.headline)
                            .foregroundColor(recordingManager.isRecording ? .red : .blue)
                    }
                }
                .disabled(diarizationManager.isProcessing)
                
                if recordingManager.hasRecording && !recordingManager.isRecording {
                    // Process button
                    Button(action: processDiarization) {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Analyze")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    .disabled(diarizationManager.isProcessing)
                    
                    // Clear button
                    Button(action: clearRecording) {
                        VStack(spacing: 8) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Clear")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(diarizationManager.isProcessing)
                }
            }
            
            // Recording status
            if recordingManager.isRecording {
                RecordingStatusView(
                    recordingTime: recordingManager.recordingTime,
                    sampleCount: recordingManager.audioSamples.count
                )
            }
            
            // Audio info
            if recordingManager.hasRecording && !recordingManager.isRecording {
                AudioInfoView(
                    duration: recordingManager.recordingTime,
                    sampleCount: recordingManager.audioSamples.count,
                    source: "Recording"
                )
            }
        }
    }
    
    private func toggleRecording() {
        if recordingManager.isRecording {
            recordingManager.stopRecording()
        } else {
            recordingManager.requestMicrophonePermission { granted in
                if granted {
                    recordingManager.startRecording()
                } else {
                    permissionDenied = true
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func processDiarization() {
        Task {
            await diarizationManager.performDiarization(
                audioSamples: audioSamples,
                sampleRate: 16000
            )
        }
    }
    
    private func clearRecording() {
        recordingManager.clearRecording()
        diarizationManager.clearSegments()
    }
}

struct UploadSection: View {
    @ObservedObject var fileManager: AudioFileManager
    @ObservedObject var diarizationManager: DiarizationManager
    @Binding var showingFilePicker: Bool
    let audioSamples: [Float]
    
    var body: some View {
        VStack(spacing: 20) {
            // Upload controls
            HStack(spacing: 20) {
                // Upload button
                Button(action: { showingFilePicker = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Choose File")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(diarizationManager.isProcessing || fileManager.isProcessing)
                
                if fileManager.hasAudio {
                    // Process button
                    Button(action: processDiarization) {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Analyze")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                    .disabled(diarizationManager.isProcessing)
                    
                    // Clear button
                    Button(action: clearAudio) {
                        VStack(spacing: 8) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Clear")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(diarizationManager.isProcessing)
                }
            }
            
            // File processing status
            if fileManager.isProcessing {
                ProgressView("Processing audio file...")
                    .padding()
            }
            
            // Audio info
            if fileManager.hasAudio {
                AudioInfoView(
                    duration: fileManager.audioDuration,
                    sampleCount: fileManager.audioSamples.count,
                    source: fileManager.fileName
                )
            }
            
            // Error display
            if let error = fileManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private func processDiarization() {
        Task {
            await diarizationManager.performDiarization(
                audioSamples: audioSamples,
                sampleRate: 16000
            )
        }
    }
    
    private func clearAudio() {
        fileManager.clearAudio()
        diarizationManager.clearSegments()
    }
}

struct AudioInfoView: View {
    let duration: TimeInterval
    let sampleCount: Int
    let source: String
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "0:00"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(source)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                Label(formattedDuration, systemImage: "clock")
                Label("\(sampleCount / 16000)s @ 16kHz", systemImage: "waveform")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.pulse, isActive: true)
            
            Text("Record or upload audio to identify speakers")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Powered by FluidAudio CoreML")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
    }
}

struct RecordingStatusView: View {
    let recordingTime: TimeInterval
    let sampleCount: Int
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: recordingTime) ?? "0:00"
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: isAnimating)
                
                Text("Recording: \(formattedTime)")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            // Audio level visualization (simple)
            HStack(spacing: 2) {
                ForEach(0..<20) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red.opacity(Double.random(in: 0.3...1.0)))
                        .frame(width: 3, height: CGFloat.random(in: 5...25))
                        .animation(.easeInOut(duration: 0.2), value: UUID())
                }
            }
            .frame(height: 25)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ProcessingView: View {
    let progress: Double
    let statusMessage: String
    
    var body: some View {
        VStack(spacing: 10) {
            ProgressView(value: progress) {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct SegmentsView: View {
    let segments: [SpeakerSegment]
    let statistics: [(speaker: String, totalTime: TimeInterval, segmentCount: Int)]
    
    @State private var selectedTab = 0
    
    var speakerColors: [String: Color] {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .cyan, .red, .yellow]
        var colorMap: [String: Color] = [:]
        
        for (index, speakerId) in Set(segments.map { $0.speakerId }).enumerated() {
            colorMap[speakerId] = colors[index % colors.count]
        }
        
        return colorMap
    }
    
    var body: some View {
        VStack {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Timeline").tag(0)
                Text("Statistics").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if selectedTab == 0 {
                // Timeline view
                TimelineView(segments: segments, speakerColors: speakerColors)
            } else {
                // Statistics view
                StatisticsView(statistics: statistics, speakerColors: speakerColors)
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct TimelineView: View {
    let segments: [SpeakerSegment]
    let speakerColors: [String: Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Speaker Timeline")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(segments) { segment in
                        SegmentRowView(
                            segment: segment,
                            color: speakerColors[segment.speakerId] ?? .gray
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
    }
}

struct StatisticsView: View {
    let statistics: [(speaker: String, totalTime: TimeInterval, segmentCount: Int)]
    let speakerColors: [String: Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Speaker Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(statistics, id: \.speaker) { stat in
                        HStack {
                            Circle()
                                .fill(speakerColors[stat.speaker] ?? .gray)
                                .frame(width: 12, height: 12)
                            
                            Text(stat.speaker)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatDuration(stat.totalTime))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(stat.segmentCount) segments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(speakerColors[stat.speaker]?.opacity(0.1) ?? Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

struct SegmentRowView: View {
    let segment: SpeakerSegment
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.speakerId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(segment.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(segment.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(String(format: "%.1f", segment.duration))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ErrorView: View {
    let error: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}