# LocalDiarizationSwiftExample

A complete iOS example app demonstrating on-device speaker diarization using FluidAudio's CoreML models. This app identifies "who spoke when" in audio recordings without requiring any cloud services.

## Features

- 🎤 **Real-time Audio Recording**: Record conversations directly from your iOS device
- 📁 **Audio File Upload**: Import existing audio files (MP3, WAV, AIFF, etc.)
- 🧠 **On-Device ML Processing**: Speaker diarization runs entirely on-device using CoreML
- 👥 **Speaker Identification**: Automatically identifies different speakers in conversations
- 📊 **Visual Results**: Timeline and statistics views with color-coded speakers
- 🔒 **Privacy-First**: All processing happens locally - no audio leaves your device

## Technologies

- **SwiftUI** - Modern declarative UI framework
- **FluidAudio** - CoreML-based speaker diarization models
- **AVFoundation** - Audio recording and processing
- **CoreML** - On-device machine learning

## Requirements

- iOS 16.0+
- Xcode 15.0+
- iPhone or iPad with A12 Bionic chip or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/LocalDiarizationSwiftExample.git
cd LocalDiarizationSwiftExample
```

2. Open in Xcode:
```bash
open LocalDiarizationTest.xcodeproj
```

3. Build and run on your device (simulator not recommended for optimal performance)

## How It Works

The app uses the [FluidInference/speaker-diarization-coreml](https://huggingface.co/FluidInference/speaker-diarization-coreml) model from HuggingFace, which provides:

1. **Voice Activity Detection**: Identifies when someone is speaking
2. **Speaker Embedding**: Creates unique voice fingerprints for each speaker
3. **Clustering**: Groups voice segments by speaker similarity

### Audio Processing Pipeline

1. Audio is captured at device's native sample rate (typically 48kHz)
2. Converted to 16kHz mono for model input
3. Processed through FluidAudio's diarization pipeline
4. Results displayed with speaker labels and confidence scores

## Usage

### Recording Mode
1. Tap the "Record" tab
2. Press the microphone button to start recording
3. Press stop when finished
4. Tap "Analyze" to process the recording

### Upload Mode
1. Tap the "Upload" tab
2. Select "Choose File" to pick an audio file
3. Tap "Analyze" to process the audio

### Understanding Results
- **Timeline View**: Shows chronological speaker segments
- **Statistics View**: Displays total speaking time per speaker
- **Confidence Scores**: Higher percentages indicate more confident speaker identification

## Configuration

The app uses optimized settings based on FluidAudio benchmarks:
- Clustering threshold: 0.7 (17.7% DER optimal)
- Minimum speech duration: 1.0 second
- Minimum silence gap: 0.5 seconds

## Architecture

```
LocalDiarizationTest/
├── AudioRecordingManager.swift    # Handles microphone recording
├── AudioFileManager.swift         # Manages file imports and conversion
├── DiarizationManager.swift       # FluidAudio model integration
└── ContentView.swift              # SwiftUI user interface
```

## Performance

- Achieves 17.7% Diarization Error Rate (DER)
- Processes audio at ~10x real-time on modern iPhones
- Models are cached after first download (~50MB)

## Privacy & Security

- All processing happens on-device
- No network requests for audio processing
- Audio files are only accessed with explicit user permission
- Microphone access requires user consent

## Known Limitations

- Batch processing only (no real-time streaming)
- Optimal for 2-8 speakers
- Best results with clear audio and minimal background noise

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

MIT License - See [LICENSE](LICENSE) file for details

## Acknowledgments

- [FluidInference](https://github.com/FluidInference/FluidAudio) for the CoreML models
- Based on pyannote's speaker diarization research

## Related Links

- [FluidAudio GitHub](https://github.com/FluidInference/FluidAudio)
- [Model on HuggingFace](https://huggingface.co/FluidInference/speaker-diarization-coreml)
- [CoreML Documentation](https://developer.apple.com/documentation/coreml)

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing issues for solutions
- Include device model and iOS version in bug reports

---

**Made with ❤️ for the iOS community**