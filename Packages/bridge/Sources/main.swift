// HamStation Bridge — HTTP + WebSocket server for native capabilities.
// Exposes rig control, DX cluster, audio, and local LLM to the web app.

import Foundation
import Hummingbird
import HamStationKit

@main
struct BridgeServer {
    static func main() async throws {
        let port = 8412

        let router = Router()

        // CORS middleware for localhost
        router.middlewares.add(CORSMiddleware())

        // Health check
        router.get("/api/health") { _, _ in
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: """
                {"status":"ok","version":"0.1.0","capabilities":["rig","cluster","audio","llm"]}
                """))
            )
        }

        // System info
        router.get("/api/system/ram") { _, _ in
            let ram = ProcessInfo.processInfo.physicalMemory
            let ramGB = Int(ram / (1024 * 1024 * 1024))
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: "{\"totalGB\":\(ramGB)}"))
            )
        }

        // NTP status
        router.get("/api/ntp/status") { _, _ in
            let status = SystemClock.checkNTPSync(thresholdMs: 500)
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: """
                {"offsetMs":\(status.offsetMilliseconds),"acceptable":\(status.isAcceptable),"description":"\(status.description)"}
                """))
            )
        }

        // Rig control stubs
        router.post("/api/rig/connect") { _, _ in
            return Response(status: .ok, headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: "{\"status\":\"not_implemented\"}")))
        }

        router.get("/api/rig/state") { _, _ in
            return Response(status: .ok, headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: "{\"frequency\":14074000,\"mode\":\"USB\",\"ptt\":false}")))
        }

        // Audio device list
        router.get("/api/audio/devices") { _, _ in
            return Response(status: .ok, headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: "{\"inputs\":[],\"outputs\":[]}")))
        }

        // LLM model list
        router.get("/api/llm/models") { _, _ in
            let models = LocalLLMEngine.modelCatalog.map { model in
                "{\"id\":\"\(model.id)\",\"name\":\"\(model.displayName)\",\"sizeGB\":\(model.sizeGB),\"minRAMGB\":\(model.minRAMGB)}"
            }.joined(separator: ",")
            return Response(status: .ok, headers: [.contentType: "application/json"],
                body: .init(byteBuffer: .init(string: "[\(models)]")))
        }

        let app = Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: port)))

        print("🌐 HamStation Bridge running on http://127.0.0.1:\(port)")
        print("   Health: http://127.0.0.1:\(port)/api/health")
        print("   Press Ctrl+C to stop")

        try await app.runService()
    }
}

/// Simple CORS middleware for localhost development.
struct CORSMiddleware: RouterMiddleware {
    func handle(_ request: Request, context: some RequestContext, next: (Request, some RequestContext) async throws -> Response) async throws -> Response {
        var response = try await next(request, context)
        response.headers[.accessControlAllowOrigin] = "*"
        response.headers[.accessControlAllowMethods] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers[.accessControlAllowHeaders] = "Content-Type, Authorization"
        return response
    }
}
