//
//  AudioFileManager.swift
//  LocalDiarizationTest
//
//  Created by Elijah Arbee on 8/20/25.
//

import Foundation
import AVFoundation
import UniformTypeIdentifiers

@MainActor
class AudioFileManager: ObservableObject {
    @Published var isProcessing = false
    @Published var audioSamples: [Float] = []
    @Published var hasAudio = false
    @Published var fileName: String = ""
    @Published var audioDuration: TimeInterval = 0
    @Published var error: String?
    
    // Process uploaded audio file
    func processAudioFile(url: URL) async {
        isProcessing = true
        error = nil
        audioSamples.removeAll()
        hasAudio = false
        fileName = url.lastPathComponent
        
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw AudioFileError.accessDenied
            }
            
            defer {
                // Stop accessing when done
                url.stopAccessingSecurityScopedResource()
            }
            
            // Load audio file
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            // Calculate duration
            audioDuration = Double(frameCount) / format.sampleRate
            
            // Create buffer for reading
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw AudioFileError.bufferCreationFailed
            }
            
            try audioFile.read(into: buffer)
            
            // Convert to 16kHz mono if needed
            let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: 16000,
                                            channels: 1,
                                            interleaved: false)!
            
            let convertedBuffer: AVAudioPCMBuffer
            
            if format.sampleRate != 16000 || format.channelCount != 1 {
                // Need conversion
                guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
                    throw AudioFileError.converterCreationFailed
                }
                
                let convertedFrameCapacity = AVAudioFrameCount(Double(frameCount) * 16000.0 / format.sampleRate)
                guard let tempBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: convertedFrameCapacity) else {
                    throw AudioFileError.bufferCreationFailed
                }
                
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                var error: NSError?
                converter.convert(to: tempBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    throw error
                }
                
                convertedBuffer = tempBuffer
            } else {
                // Already in correct format
                convertedBuffer = buffer
            }
            
            // Extract samples
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(
                    start: channelData,
                    count: Int(convertedBuffer.frameLength)
                ))
                
                await MainActor.run {
                    self.audioSamples = samples
                    self.hasAudio = true
                    self.isProcessing = false
                }
            } else {
                throw AudioFileError.sampleExtractionFailed
            }
            
        } catch {
            await MainActor.run {
                self.error = "Failed to process audio file: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    func clearAudio() {
        audioSamples.removeAll()
        hasAudio = false
        fileName = ""
        audioDuration = 0
        error = nil
    }
    
    // Get supported audio types for file picker
    static var supportedTypes: [UTType] {
        [.audio, .mp3, .wav, .aiff, .mpeg4Audio]
    }
}

enum AudioFileError: LocalizedError {
    case bufferCreationFailed
    case converterCreationFailed
    case sampleExtractionFailed
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .sampleExtractionFailed:
            return "Failed to extract audio samples"
        case .accessDenied:
            return "Failed to access audio file. Please try selecting it again."
        }
    }
}