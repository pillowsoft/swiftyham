import XCTest
import Foundation
@testable import HamStationKit

// MARK: - Mock URL Protocol

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (Data, HTTPURLResponse))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestCount += 1

        guard let handler = Self.requestHandler else {
            let error = NSError(domain: "MockURLProtocol", code: 0, userInfo: [NSLocalizedDescriptionKey: "No handler set"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helper

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeHTTPResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
}

// MARK: - Tests

class ResilientClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.requestCount = 0
        MockURLProtocol.requestHandler = nil
    }

    func testSuccessfulFetch() async throws {
        let expectedData = Data("hello world".utf8)
        let url = URL(string: "https://example.com/test")!

        MockURLProtocol.requestHandler = { _ in
            (expectedData, makeHTTPResponse(url: url))
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)

        let (data, _) = try await client.fetch(request, service: "test")

        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    func testRetryThenSuccess() async throws {
        let url = URL(string: "https://example.com/retry")!
        let expectedData = Data("success".utf8)
        var attemptCount = 0

        MockURLProtocol.requestHandler = { _ in
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.badServerResponse)
            }
            return (expectedData, makeHTTPResponse(url: url))
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 3, baseDelay: 0.01)

        let (data, _) = try await client.fetch(request, service: "test", config: config)

        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(attemptCount, 3)
    }

    func testAllRetriesExhausted() async throws {
        let url = URL(string: "https://example.com/fail")!

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.badServerResponse)
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 3, baseDelay: 0.01, staleCacheOK: false)

        do {
            _ = try await client.fetch(request, service: "test", config: config)
            XCTFail("Expected error to be thrown")
        } catch is ResilientClientError {
            // Expected
        } catch {
            XCTFail("Expected ResilientClientError, got \(error)")
        }

        XCTAssertEqual(MockURLProtocol.requestCount, 3)
    }

    func testStaleCacheFallback() async throws {
        let url = URL(string: "https://example.com/stale")!
        let cachedData = Data("cached response".utf8)
        var shouldFail = false

        MockURLProtocol.requestHandler = { _ in
            if shouldFail {
                throw URLError(.badServerResponse)
            }
            return (cachedData, makeHTTPResponse(url: url))
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 1, baseDelay: 0.01, staleCacheOK: true)

        let (data1, _) = try await client.fetch(request, service: "test", config: config)
        XCTAssertEqual(data1, cachedData)

        shouldFail = true
        let (data2, _) = try await client.fetch(request, service: "test", config: config)
        XCTAssertEqual(data2, cachedData)
    }

    func testStaleCacheDisabled() async throws {
        let url = URL(string: "https://example.com/nocache")!
        let cachedData = Data("cached".utf8)
        var shouldFail = false

        MockURLProtocol.requestHandler = { _ in
            if shouldFail {
                throw URLError(.badServerResponse)
            }
            return (cachedData, makeHTTPResponse(url: url))
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 1, baseDelay: 0.01, staleCacheOK: false)

        _ = try await client.fetch(request, service: "test", config: config)

        shouldFail = true
        do {
            _ = try await client.fetch(request, service: "test", config: config)
            XCTFail("Expected error to be thrown")
        } catch is ResilientClientError {
            // Expected
        } catch {
            XCTFail("Expected ResilientClientError, got \(error)")
        }
    }

    func testTimeoutError() async throws {
        let url = URL(string: "https://example.com/timeout")!

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 1, baseDelay: 0.01, staleCacheOK: false)

        do {
            _ = try await client.fetch(request, service: "test", config: config)
            XCTFail("Expected error to be thrown")
        } catch let error as ResilientClientError {
            switch error {
            case .allRetriesFailed(let errors):
                XCTAssertFalse(errors.isEmpty)
            case .timeout:
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testNetworkUnavailable() async throws {
        let url = URL(string: "https://example.com/offline")!

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 1, baseDelay: 0.01, staleCacheOK: false)

        do {
            _ = try await client.fetch(request, service: "test", config: config)
            XCTFail("Expected error to be thrown")
        } catch let error as ResilientClientError {
            switch error {
            case .allRetriesFailed(let errors):
                XCTAssertFalse(errors.isEmpty)
            case .networkUnavailable:
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testFetchJSON() async throws {
        struct TestModel: Decodable, Sendable, Equatable {
            let name: String
            let value: Int
        }

        let url = URL(string: "https://example.com/json")!
        let jsonData = Data(#"{"name":"test","value":42}"#.utf8)

        MockURLProtocol.requestHandler = { _ in
            (jsonData, makeHTTPResponse(url: url))
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)

        let result: TestModel = try await client.fetchJSON(request, service: "test")
        XCTAssertEqual(result.name, "test")
        XCTAssertEqual(result.value, 42)
    }

    func testRateLimiterAllowsRequests() async throws {
        let url = URL(string: "https://example.com/ratelimit")!
        let responseData = Data("ok".utf8)

        MockURLProtocol.requestHandler = { _ in
            (responseData, makeHTTPResponse(url: url))
        }

        let session = makeMockSession()
        let client = ResilientClient(session: session)
        let request = URLRequest(url: url)
        let config = ServiceConfig(maxRetries: 1, baseDelay: 0.01, maxRequestsPerMinute: 100)

        for _ in 0..<5 {
            let (data, _) = try await client.fetch(request, service: "ratelimit-test", config: config)
            XCTAssertEqual(data, responseData)
        }

        XCTAssertEqual(MockURLProtocol.requestCount, 5)
    }
}
