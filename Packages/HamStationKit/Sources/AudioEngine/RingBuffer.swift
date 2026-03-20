// RingBuffer.swift
// HamStationKit — Lock-free SPSC ring buffer for audio samples.

import AVFoundation
import os

/// Lock-free, single-producer single-consumer ring buffer for audio samples.
///
/// This is the core primitive connecting the real-time audio thread to async consumers.
/// The producer (audio callback) calls `write`; the consumer (FFT/decoder) calls `read`.
/// No locks, no allocations on the hot path.
///
/// `@unchecked Sendable` because the SPSC (single-producer, single-consumer) contract
/// guarantees correctness:
/// - `_writeIndex` is only mutated by the producer
/// - `_readIndex` is only mutated by the consumer
/// - Thread safety for index reads is provided by `OSAllocatedUnfairLock`.
public final class AudioRingBuffer: @unchecked Sendable {

    /// Total number of Float samples this buffer can hold.
    public let capacity: Int

    private let buffer: UnsafeMutablePointer<Float>
    private let mask: Int

    // Thread-safe indices using OSAllocatedUnfairLock.
    private let _writeIndex: OSAllocatedUnfairLock<Int>
    private let _readIndex: OSAllocatedUnfairLock<Int>

    /// Create a ring buffer.
    /// - Parameter capacity: Number of Float samples. Rounded up to next power of two.
    public init(capacity: Int) {
        // Round up to power of two for fast modulo via bitwise AND.
        let powerOfTwo = capacity <= 0 ? 1024 : (1 << Int(ceil(log2(Double(capacity)))))
        self.capacity = powerOfTwo
        self.mask = powerOfTwo - 1

        self.buffer = .allocate(capacity: powerOfTwo)
        self.buffer.initialize(repeating: 0.0, count: powerOfTwo)

        self._writeIndex = OSAllocatedUnfairLock(initialState: 0)
        self._readIndex = OSAllocatedUnfairLock(initialState: 0)
    }

    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }

    // MARK: - Index helpers

    private var writeIndex: Int {
        get { _writeIndex.withLock { $0 } }
        set { _writeIndex.withLock { $0 = newValue } }
    }

    private var readIndex: Int {
        get { _readIndex.withLock { $0 } }
        set { _readIndex.withLock { $0 = newValue } }
    }

    // MARK: - Availability

    /// Number of samples available for reading.
    public var availableToRead: Int {
        let w = writeIndex
        let r = readIndex
        return w &- r
    }

    /// Space available for writing (in samples).
    public var availableToWrite: Int {
        capacity - availableToRead
    }

    // MARK: - Producer (real-time safe)

    /// Write samples from an unsafe buffer pointer. Called from audio callback thread.
    ///
    /// Real-time safe: no allocation, no locks, no Swift async.
    /// - Returns: Number of samples actually written.
    @discardableResult
    public func write(_ samples: UnsafeBufferPointer<Float>) -> Int {
        let count = min(samples.count, availableToWrite)
        guard count > 0 else { return 0 }

        let w = writeIndex
        let startPos = w & mask
        let firstChunk = min(count, capacity - startPos)
        let secondChunk = count - firstChunk

        // Copy first segment (to end of physical buffer)
        buffer.advanced(by: startPos).update(from: samples.baseAddress!, count: firstChunk)

        // Copy wrap-around segment (from start of physical buffer)
        if secondChunk > 0 {
            buffer.update(from: samples.baseAddress!.advanced(by: firstChunk), count: secondChunk)
        }

        writeIndex = w &+ count
        return count
    }

    /// Write samples from an `AVAudioPCMBuffer`. Called from audio callback thread.
    ///
    /// Extracts channel 0 (mono) float data. Real-time safe.
    /// - Returns: Number of samples actually written.
    @discardableResult
    public func write(from pcmBuffer: AVAudioPCMBuffer) -> Int {
        guard let channelData = pcmBuffer.floatChannelData else { return 0 }
        let frameCount = Int(pcmBuffer.frameLength)
        let ptr = UnsafeBufferPointer(start: channelData[0], count: frameCount)
        return write(ptr)
    }

    // MARK: - Consumer (async-safe)

    /// Read samples into a pre-allocated destination buffer.
    /// - Returns: Number of samples actually read.
    @discardableResult
    public func read(into destination: UnsafeMutableBufferPointer<Float>) -> Int {
        let count = min(destination.count, availableToRead)
        guard count > 0 else { return 0 }

        let r = readIndex
        let startPos = r & mask
        let firstChunk = min(count, capacity - startPos)
        let secondChunk = count - firstChunk

        destination.baseAddress!.update(from: buffer.advanced(by: startPos), count: firstChunk)

        if secondChunk > 0 {
            destination.baseAddress!.advanced(by: firstChunk)
                .update(from: buffer, count: secondChunk)
        }

        readIndex = r &+ count
        return count
    }

    /// Convenience: read `count` samples into a new `[Float]` array.
    ///
    /// Allocates — do NOT call from the real-time thread.
    /// - Returns: Array of samples, or `nil` if fewer than `count` samples are available.
    public func read(count: Int) -> [Float]? {
        guard availableToRead >= count else { return nil }
        var result = [Float](repeating: 0.0, count: count)
        result.withUnsafeMutableBufferPointer { buf in
            _ = read(into: buf)
        }
        return result
    }

    /// Skip (discard) samples without reading them. Used by decoders to catch up.
    public func skip(_ count: Int) {
        let toSkip = min(count, availableToRead)
        let r = readIndex
        readIndex = r &+ toSkip
    }

    /// Reset the buffer, discarding all data. Call only when pipeline is stopped.
    public func reset() {
        readIndex = 0
        writeIndex = 0
    }
}
