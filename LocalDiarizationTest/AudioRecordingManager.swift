//
//  AudioRecordingManager.swift
//  LocalDiarizationTest
//
//  Created by Elijah Arbee on 8/20/25.
//

import Foundation
import AVFoundation
import AVFAudio
import Combine

class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioSamples: [Float] = []
    @Published var recordingTime: TimeInterval = 0
    @Published var hasRecording = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var recordingTimer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }
    
    func startRecording() {
        audioSamples.removeAll()
        hasRecording = false
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else { return }
        
        // Get the hardware format (native format of the input node)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create desired output format (16kHz for diarization)
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        
        // Create a converter if needed
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        
        // Install tap with the hardware format (not the desired format)
        // Use smaller buffer for more frequent callbacks in real-time mode
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,  // Smaller buffer for more frequent updates
            format: inputFormat  // Use hardware format here
        ) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Convert to 16kHz if needed
            if let converter = converter {
                let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate)
                )!
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    print("Conversion error: \(error)")
                    return
                }
                
                // Extract samples from converted buffer
                if let channelData = convertedBuffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(
                        start: channelData,
                        count: Int(convertedBuffer.frameLength)
                    ))
                    DispatchQueue.main.async {
                        self.audioSamples.append(contentsOf: samples)
                    }
                }
            } else {
                // If no conversion needed, use buffer directly
                if let channelData = buffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(
                        start: channelData,
                        count: Int(buffer.frameLength)
                    ))
                    DispatchQueue.main.async {
                        self.audioSamples.append(contentsOf: samples)
                    }
                }
            }
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            startTime = Date()
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.startTime else { return }
                self.recordingTime = Date().timeIntervalSince(startTime)
            }
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopRecording() {
        guard let audioEngine = audioEngine else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine.stop()
        
        isRecording = false
        hasRecording = !audioSamples.isEmpty
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        self.audioEngine = nil
        self.inputNode = nil
    }
    
    func clearRecording() {
        audioSamples.removeAll()
        hasRecording = false
        recordingTime = 0
    }
}