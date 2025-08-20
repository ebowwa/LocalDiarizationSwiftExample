//
//  DiarizationManager.swift
//  LocalDiarizationTest
//
//  Created by Elijah Arbee on 8/20/25.
//

import Foundation
import Combine
import FluidAudio

struct SpeakerSegment: Identifiable {
    let id = UUID()
    let speakerId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var formattedTimeRange: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        let start = formatter.string(from: startTime) ?? "0:00"
        let end = formatter.string(from: endTime) ?? "0:00"
        
        return "\(start) - \(end)"
    }
}

@MainActor
class DiarizationManager: ObservableObject {
    @Published var isProcessing = false
    @Published var segments: [SpeakerSegment] = []
    @Published var error: String?
    @Published var processingProgress: Double = 0.0
    @Published var statusMessage: String = ""
    
    // FluidAudio Diarizer
    private var diarizer: DiarizerManager?
    private var models: DiarizerModels?
    
    // MARK: - Initialization
    
    private func initializeDiarizer(config: DiarizerConfig) async throws {
        guard diarizer == nil else { return }
        
        await MainActor.run {
            self.statusMessage = "Loading AI models..."
            self.processingProgress = 0.1
        }
        
        // Download and load the models (cached after first download)
        models = try await DiarizerModels.download()
        
        await MainActor.run {
            self.statusMessage = "Initializing diarizer..."
            self.processingProgress = 0.2
        }
        
        // Initialize the diarizer with config
        diarizer = DiarizerManager(config: config)
        if let models = models {
            diarizer?.initialize(models: models)
        }
    }
    
    // MARK: - Batch Processing
    
    func performDiarization(audioSamples: [Float], sampleRate: Int = 16000) async {
        await MainActor.run {
            self.isProcessing = true
            self.error = nil
            self.segments = []
            self.processingProgress = 0.0
            self.statusMessage = "Starting processing..."
        }
        
        do {
            // Configure diarization parameters for optimal results
            let config = DiarizerConfig(
                clusteringThreshold: 0.7,  // Optimal from FluidAudio benchmarks
                minSpeechDuration: 1.0,
                minEmbeddingUpdateDuration: 2.0,
                minSilenceGap: 0.5,
                numClusters: -1,  // Auto-detect number of speakers
                minActiveFramesCount: 10.0,
                debugMode: false
            )
            
            // Initialize diarizer with config if needed
            try await initializeDiarizer(config: config)
            
            guard let diarizer = diarizer else {
                throw DiarizationError.initializationFailed
            }
            
            await MainActor.run {
                self.statusMessage = "Analyzing speakers..."
                self.processingProgress = 0.3
            }
            
            await MainActor.run {
                self.statusMessage = "Processing audio (\(Int(Double(audioSamples.count) / Double(sampleRate))) seconds)..."
                self.processingProgress = 0.5
            }
            
            // Perform complete diarization (synchronous)
            let result = try diarizer.performCompleteDiarization(
                audioSamples,
                sampleRate: sampleRate
            )
            
            await MainActor.run {
                self.statusMessage = "Finalizing results..."
                self.processingProgress = 0.8
            }
            
            // Convert results to our segment format
            let processedSegments = result.segments.map { segment in
                SpeakerSegment(
                    speakerId: segment.speakerId,
                    startTime: TimeInterval(segment.startTimeSeconds),
                    endTime: TimeInterval(segment.endTimeSeconds),
                    confidence: segment.qualityScore
                )
            }
            
            // Sort segments by start time
            let sortedSegments = processedSegments.sorted { $0.startTime < $1.startTime }
            
            await MainActor.run {
                self.segments = sortedSegments
                self.isProcessing = false
                self.processingProgress = 1.0
                self.statusMessage = "Found \(Set(sortedSegments.map { $0.speakerId }).count) speakers"
                
                // Clear status message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.statusMessage = ""
                }
            }
            
        } catch {
            await MainActor.run {
                self.error = "Diarization failed: \(error.localizedDescription)"
                self.isProcessing = false
                self.statusMessage = "Processing failed"
            }
        }
    }
    
    func clearSegments() {
        segments = []
        error = nil
        processingProgress = 0.0
        statusMessage = ""
    }
    
    // MARK: - Statistics
    
    func getSpeakerStatistics() -> [(speaker: String, totalTime: TimeInterval, segmentCount: Int)] {
        var stats: [String: (time: TimeInterval, count: Int)] = [:]
        
        for segment in segments {
            let current = stats[segment.speakerId] ?? (time: 0, count: 0)
            stats[segment.speakerId] = (
                time: current.time + segment.duration,
                count: current.count + 1
            )
        }
        
        return stats.map { (speaker: $0.key, totalTime: $0.value.time, segmentCount: $0.value.count) }
            .sorted { $0.totalTime > $1.totalTime }
    }
}

enum DiarizationError: Error {
    case initializationFailed
    case processingFailed
}