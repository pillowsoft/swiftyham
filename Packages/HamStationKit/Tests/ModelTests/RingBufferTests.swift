// RingBufferTests.swift
// HamStationKit — Tests for the lock-free SPSC AudioRingBuffer.

import XCTest
import Foundation
@testable import HamStationKit

class RingBufferTests: XCTestCase {

    // MARK: - Basic Read/Write

    func testWriteAndReadBasic() {
        let buffer = AudioRingBuffer(capacity: 1024)
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]

        samples.withUnsafeBufferPointer { ptr in
            let written = buffer.write(ptr)
            XCTAssertEqual(written, 5)
        }

        guard let result = buffer.read(count: 5) else {
            XCTFail("Expected to read 5 samples")
            return
        }

        XCTAssertEqual(result, samples)
    }

    func testWriteFillsReadEmpties() {
        let buffer = AudioRingBuffer(capacity: 16)
        let capacity = buffer.capacity

        let samples = [Float](repeating: 0.5, count: capacity)
        samples.withUnsafeBufferPointer { ptr in
            let written = buffer.write(ptr)
            XCTAssertEqual(written, capacity)
        }

        XCTAssertEqual(buffer.availableToRead, capacity)
        XCTAssertEqual(buffer.availableToWrite, 0)

        guard let result = buffer.read(count: capacity) else {
            XCTFail("Expected to read \(capacity) samples")
            return
        }

        XCTAssertEqual(result.count, capacity)
        XCTAssertEqual(buffer.availableToRead, 0)
        XCTAssertEqual(buffer.availableToWrite, capacity)
    }

    // MARK: - Overflow / Wrap

    func testOverflowWriteReturnsPartial() {
        let buffer = AudioRingBuffer(capacity: 8)
        let capacity = buffer.capacity

        let tooMany = [Float](repeating: 1.0, count: capacity + 10)
        tooMany.withUnsafeBufferPointer { ptr in
            let written = buffer.write(ptr)
            XCTAssertEqual(written, capacity)
        }

        XCTAssertEqual(buffer.availableToRead, capacity)
    }

    func testWrapAround() {
        let buffer = AudioRingBuffer(capacity: 8)

        let first: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        first.withUnsafeBufferPointer { ptr in
            _ = buffer.write(ptr)
        }

        guard let _ = buffer.read(count: 4) else {
            XCTFail("Expected to read 4 samples")
            return
        }

        let second: [Float] = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]
        second.withUnsafeBufferPointer { ptr in
            let written = buffer.write(ptr)
            XCTAssertEqual(written, 6)
        }

        XCTAssertEqual(buffer.availableToRead, 8)

        guard let result = buffer.read(count: 8) else {
            XCTFail("Expected to read 8 samples")
            return
        }

        XCTAssertEqual(result[0], 5.0)
        XCTAssertEqual(result[1], 6.0)
        XCTAssertEqual(result[2], 10.0)
        XCTAssertEqual(result[7], 60.0)
    }

    // MARK: - Availability Reporting

    func testAvailableToReadCorrect() {
        let buffer = AudioRingBuffer(capacity: 256)
        XCTAssertEqual(buffer.availableToRead, 0)

        let samples = [Float](repeating: 0, count: 100)
        samples.withUnsafeBufferPointer { ptr in
            _ = buffer.write(ptr)
        }
        XCTAssertEqual(buffer.availableToRead, 100)

        _ = buffer.read(count: 30)
        XCTAssertEqual(buffer.availableToRead, 70)
    }

    func testAvailableToWriteCorrect() {
        let buffer = AudioRingBuffer(capacity: 256)
        let capacity = buffer.capacity
        XCTAssertEqual(buffer.availableToWrite, capacity)

        let samples = [Float](repeating: 0, count: 100)
        samples.withUnsafeBufferPointer { ptr in
            _ = buffer.write(ptr)
        }
        XCTAssertEqual(buffer.availableToWrite, capacity - 100)
    }

    // MARK: - Skip

    func testSkipAdvancesReadPointer() {
        let buffer = AudioRingBuffer(capacity: 256)

        let samples: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        samples.withUnsafeBufferPointer { ptr in
            _ = buffer.write(ptr)
        }

        buffer.skip(3)
        XCTAssertEqual(buffer.availableToRead, 2)

        guard let result = buffer.read(count: 2) else {
            XCTFail("Expected to read 2 samples after skip")
            return
        }
        XCTAssertEqual(result, [4.0, 5.0])
    }

    func testSkipMoreThanAvailable() {
        let buffer = AudioRingBuffer(capacity: 256)

        let samples: [Float] = [1.0, 2.0, 3.0]
        samples.withUnsafeBufferPointer { ptr in
            _ = buffer.write(ptr)
        }

        buffer.skip(100)
        XCTAssertEqual(buffer.availableToRead, 0)
    }

    // MARK: - Reset

    func testResetClearsBuffer() {
        let buffer = AudioRingBuffer(capacity: 256)
        let capacity = buffer.capacity

        let samples = [Float](repeating: 1.0, count: 200)
        samples.withUnsafeBufferPointer { ptr in
            _ = buffer.write(ptr)
        }
        _ = buffer.read(count: 50)

        buffer.reset()
        XCTAssertEqual(buffer.availableToRead, 0)
        XCTAssertEqual(buffer.availableToWrite, capacity)

        let fresh: [Float] = [42.0]
        fresh.withUnsafeBufferPointer { ptr in
            let written = buffer.write(ptr)
            XCTAssertEqual(written, 1)
        }
        guard let result = buffer.read(count: 1) else {
            XCTFail("Expected to read 1 sample after reset")
            return
        }
        XCTAssertEqual(result, [42.0])
    }

    // MARK: - AVAudioPCMBuffer-like Data

    func testWriteFromFloatPointer() {
        let buffer = AudioRingBuffer(capacity: 1024)

        let frameCount = 128
        let audioData = [Float](repeating: 0.75, count: frameCount)

        audioData.withUnsafeBufferPointer { ptr in
            let written = buffer.write(ptr)
            XCTAssertEqual(written, frameCount)
        }

        XCTAssertEqual(buffer.availableToRead, frameCount)

        guard let result = buffer.read(count: frameCount) else {
            XCTFail("Expected to read \(frameCount) samples")
            return
        }
        XCTAssertTrue(result.allSatisfy { $0 == 0.75 })
    }

    // MARK: - Concurrent Producer/Consumer Simulation

    func testConcurrentProducerConsumer() async {
        let buffer = AudioRingBuffer(capacity: 8192)
        let totalSamples = 4096
        let chunkSize = 64

        let producerTask = Task.detached {
            var written = 0
            while written < totalSamples {
                let remaining = totalSamples - written
                let count = min(chunkSize, remaining)
                let chunk = [Float](repeating: Float(written), count: count)
                chunk.withUnsafeBufferPointer { ptr in
                    let w = buffer.write(ptr)
                    written += w
                }
                if written % 256 == 0 {
                    await Task.yield()
                }
            }
            return written
        }

        let consumerTask = Task.detached {
            var totalRead = 0
            var iterations = 0
            let maxIterations = 100_000
            while totalRead < totalSamples, iterations < maxIterations {
                iterations += 1
                let available = buffer.availableToRead
                if available > 0 {
                    let toRead = min(available, chunkSize)
                    if let samples = buffer.read(count: toRead) {
                        totalRead += samples.count
                    }
                } else {
                    await Task.yield()
                }
            }
            return totalRead
        }

        let written = await producerTask.value
        let read = await consumerTask.value

        XCTAssertEqual(written, totalSamples)
        XCTAssertEqual(read, totalSamples)
    }

    // MARK: - Empty Read

    func testEmptyReadReturnsZero() {
        let buffer = AudioRingBuffer(capacity: 256)

        let result = buffer.read(count: 1)
        XCTAssertNil(result)

        var dest = [Float](repeating: 0, count: 10)
        let readCount = dest.withUnsafeMutableBufferPointer { ptr in
            buffer.read(into: ptr)
        }
        XCTAssertEqual(readCount, 0)
    }

    // MARK: - Capacity Rounding

    func testCapacityRoundsUp() {
        let buffer = AudioRingBuffer(capacity: 100)
        XCTAssertEqual(buffer.capacity, 128)

        let buffer2 = AudioRingBuffer(capacity: 1024)
        XCTAssertEqual(buffer2.capacity, 1024)

        let buffer3 = AudioRingBuffer(capacity: 1)
        XCTAssertEqual(buffer3.capacity, 1)
    }
}
