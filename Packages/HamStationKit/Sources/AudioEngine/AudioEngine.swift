// AudioEngine.swift
// HamStationKit — Core audio pipeline owning AVAudioEngine and ring buffers.

import AVFoundation
import CoreAudio
import Foundation

// MARK: - Error types

/// Errors from AudioEngine operations.
public enum AudioEngineError: Error, Sendable {
    case deviceNotFound
    case configurationFailed(String)
    case engineStartFailed(String)
    case permissionDenied
}

// MARK: - Device info

/// Describes a CoreAudio device available for input or output.
public struct AudioDeviceInfo: Sendable, Identifiable, Equatable, Hashable {
    public let id: AudioDeviceID
    public let name: String
    public let sampleRate: Double
    public let channels: Int

    public init(id: AudioDeviceID, name: String, sampleRate: Double, channels: Int) {
        self.id = id
        self.name = name
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

// MARK: - AudioEngine actor

/// Owns `AVAudioEngine` and manages the audio processing pipeline.
///
/// Provides ring buffers for waterfall (FFT) and decoder consumers.
/// The tap callback runs on the real-time audio thread and NEVER allocates,
/// locks, or awaits -- it only copies samples into ring buffers.
public actor AudioEngine {

    // MARK: - Properties

    private let engine = AVAudioEngine()

    /// Ring buffer feeding the FFT / waterfall consumer.
    public let fftRingBuffer: AudioRingBuffer

    /// Ring buffer feeding the decoder consumer (CW, FT8, PSK31, etc.).
    public let decodeRingBuffer: AudioRingBuffer

    /// Whether the engine is currently running.
    public private(set) var isRunning: Bool = false

    /// Current sample rate (negotiated with the device).
    public private(set) var sampleRate: Double = 48000

    /// Currently selected input device, if any.
    public private(set) var inputDevice: AudioDeviceInfo?

    /// Currently selected output device, if any.
    public private(set) var outputDevice: AudioDeviceInfo?

    // MARK: - Init

    /// Create an AudioEngine with ring buffers sized for the given duration at the given rate.
    /// - Parameters:
    ///   - bufferSeconds: How many seconds of audio each ring buffer holds. Default 5.
    ///   - sampleRate: Initial sample rate assumption. Default 48000.
    public init(bufferSeconds: Int = 5, sampleRate: Double = 48000) {
        let capacity = Int(sampleRate) * bufferSeconds
        self.fftRingBuffer = AudioRingBuffer(capacity: capacity)
        self.decodeRingBuffer = AudioRingBuffer(capacity: capacity)
        self.sampleRate = sampleRate
    }

    // MARK: - Device enumeration (macOS CoreAudio)

    /// List all available audio input devices.
    public nonisolated func listInputDevices() -> [AudioDeviceInfo] {
        Self.enumerateDevices(forInput: true)
    }

    /// List all available audio output devices.
    public nonisolated func listOutputDevices() -> [AudioDeviceInfo] {
        Self.enumerateDevices(forInput: false)
    }

    /// Select an input device by `AudioDeviceInfo`.
    public func selectInputDevice(_ device: AudioDeviceInfo) throws {
        let audioUnit = engine.inputNode.audioUnit!
        var deviceID = device.id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.configurationFailed(
                "Failed to set input device '\(device.name)' (OSStatus \(status))")
        }
        self.inputDevice = device
    }

    /// Select an output device by `AudioDeviceInfo`.
    public func selectOutputDevice(_ device: AudioDeviceInfo) throws {
        let audioUnit = engine.outputNode.audioUnit!
        var deviceID = device.id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.configurationFailed(
                "Failed to set output device '\(device.name)' (OSStatus \(status))")
        }
        self.outputDevice = device
    }

    // MARK: - Start / Stop

    /// Start the audio engine and install the input tap.
    ///
    /// The tap callback copies every buffer into both ring buffers.
    /// It runs on the real-time audio thread — NO allocations, NO locks, NO async.
    public func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        self.sampleRate = hwFormat.sampleRate

        // Capture ring buffer references for the closure (no self capture).
        let fftBuf = fftRingBuffer
        let decodeBuf = decodeRingBuffer

        let tapBufferSize: AVAudioFrameCount = 1024

        inputNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: hwFormat) {
            (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            // REAL-TIME THREAD — no allocation, no locks, no async.
            fftBuf.write(from: buffer)
            decodeBuf.write(from: buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioEngineError.engineStartFailed(error.localizedDescription)
        }
        isRunning = true
    }

    /// Stop the audio engine, remove the tap, and reset ring buffers.
    public func stop() {
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        fftRingBuffer.reset()
        decodeRingBuffer.reset()

        isRunning = false
    }

    // MARK: - Async streams for consumers

    /// An `AsyncStream` of FFT magnitude spectra (in dB) for the waterfall display.
    ///
    /// Each yielded array has `fftSize / 2` elements.
    /// Implements drop policy: if the ring buffer has more than 2x `fftSize` samples
    /// queued, it skips ahead to the latest data.
    public func fftStream(fftSize: Int = 4096) -> AsyncStream<[Float]> {
        let ringBuffer = fftRingBuffer
        let processor = FFTProcessor(fftSize: fftSize, sampleRate: sampleRate)
        let running = isRunning

        return AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                guard running else {
                    continuation.finish()
                    return
                }
                while !Task.isCancelled {
                    let available = ringBuffer.availableToRead

                    // Drop policy: if we're more than 2 FFT frames behind, skip ahead.
                    if available > fftSize * 2 {
                        ringBuffer.skip(available - fftSize)
                    }

                    if let samples = ringBuffer.read(count: fftSize) {
                        let magnitudes = processor.process(samples)
                        continuation.yield(magnitudes)
                    } else {
                        // Not enough samples yet — brief sleep (real-time budget).
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// An `AsyncStream` of raw audio chunks for decoders (CW, FT8, PSK31, etc.).
    ///
    /// Each yielded array has `chunkSize` Float samples (default 960 = 20ms at 48kHz).
    /// Implements drop policy: if the ring buffer is more than 0.5s behind, skip ahead.
    public func decoderAudioStream(chunkSize: Int = 960) -> AsyncStream<[Float]> {
        let ringBuffer = decodeRingBuffer
        let rate = sampleRate
        let running = isRunning

        return AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                guard running else {
                    continuation.finish()
                    return
                }
                let maxBacklog = Int(rate * 0.5) // 0.5 seconds
                while !Task.isCancelled {
                    let available = ringBuffer.availableToRead

                    // Drop policy: if more than 0.5s behind, skip to latest.
                    if available > maxBacklog {
                        ringBuffer.skip(available - chunkSize)
                    }

                    if let samples = ringBuffer.read(count: chunkSize) {
                        continuation.yield(samples)
                    } else {
                        try? await Task.sleep(for: .milliseconds(5))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - CoreAudio device enumeration (private)

    private nonisolated static func enumerateDevices(forInput: Bool) -> [AudioDeviceInfo] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { return [] }

        let targetScope = forInput
            ? kAudioDevicePropertyScopeInput
            : kAudioDevicePropertyScopeOutput

        var results: [AudioDeviceInfo] = []
        for deviceID in deviceIDs {
            // Check if device has streams in the target scope
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: targetScope,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize)
            guard status == noErr, streamSize > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
            let deviceName = status == noErr ? name as String : "Unknown"

            // Get nominal sample rate
            var rateAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nominalRate: Float64 = 0
            var rateSize = UInt32(MemoryLayout<Float64>.size)
            _ = AudioObjectGetPropertyData(deviceID, &rateAddress, 0, nil, &rateSize, &nominalRate)

            // Get channel count
            var channelAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: targetScope,
                mElement: kAudioObjectPropertyElementMain
            )
            var bufferListSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(
                deviceID, &channelAddress, 0, nil, &bufferListSize)
            var channelCount = 0
            if status == noErr, bufferListSize > 0 {
                let bufferListPtr = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                defer { bufferListPtr.deallocate() }
                let rawSize = bufferListSize
                status = AudioObjectGetPropertyData(
                    deviceID, &channelAddress, 0, nil, &bufferListSize, bufferListPtr)
                if status == noErr {
                    let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPtr)
                    for buf in bufferList {
                        channelCount += Int(buf.mNumberChannels)
                    }
                }
            }

            results.append(AudioDeviceInfo(
                id: deviceID,
                name: deviceName,
                sampleRate: nominalRate > 0 ? nominalRate : 48000,
                channels: channelCount
            ))
        }
        return results
    }
}
