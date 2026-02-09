//
//  NetworkService.swift
//  Moment
//
//  Network monitoring and retry logic for resilient API calls
//

import Foundation
import Network

@Observable
final class NetworkService {
    static let shared = NetworkService()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Network state
    var isConnected: Bool = true
    var connectionType: ConnectionType = .unknown
    
    // Pending operations queue
    private var pendingOperations: [PendingOperation] = []
    private let operationsKey = "pendingNetworkOperations"
    
    private init() {
        startMonitoring()
        loadPendingOperations()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                // Process pending operations when back online
                if path.status == .satisfied {
                    self?.processPendingOperations()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
    
    // MARK: - Retry Logic
    
    /// Execute an async operation with retry logic
    func withRetry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if isNonRetryableError(error) {
                    throw error
                }
                
                // Don't wait after last attempt
                if attempt < maxAttempts {
                    print("⚠️ Attempt \(attempt) failed, retrying in \(currentDelay)s...")
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= backoffMultiplier
                }
            }
        }
        
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
    
    private func isNonRetryableError(_ error: Error) -> Bool {
        // Don't retry cancellation errors (user navigated away)
        if error is CancellationError {
            return true
        }
        
        // Don't retry authentication errors or validation errors
        let errorString = error.localizedDescription.lowercased()
        return errorString.contains("unauthorized") ||
               errorString.contains("invalid") ||
               errorString.contains("not found") ||
               errorString.contains("forbidden") ||
               errorString.contains("cancel")
    }
    
    // MARK: - Offline Queue
    
    /// Queue an operation to be executed when online
    func queueOperation(_ operation: PendingOperation) {
        pendingOperations.append(operation)
        savePendingOperations()
        print("📥 Queued operation: \(operation.type)")
    }
    
    /// Process all pending operations
    func processPendingOperations() {
        guard isConnected, !pendingOperations.isEmpty else { return }
        
        print("🔄 Processing \(pendingOperations.count) pending operations...")
        
        Task {
            for operation in pendingOperations {
                do {
                    try await executeOperation(operation)
                    await MainActor.run {
                        pendingOperations.removeAll { $0.id == operation.id }
                        savePendingOperations()
                    }
                    print("✅ Completed queued operation: \(operation.type)")
                } catch {
                    print("❌ Failed to process operation: \(error)")
                    // Keep in queue for next attempt
                }
            }
        }
    }
    
    private func executeOperation(_ operation: PendingOperation) async throws {
        switch operation.type {
        case .updateProfile:
            if let data = operation.data,
               let name = data["name"] {
                _ = try await SupabaseService.shared.updateProfile(ProfileUpdate(name: name))
            }
            
        case .logLHTest:
            if let data = operation.data,
               let cycleIdString = data["cycleId"],
               let cycleId = UUID(uuidString: cycleIdString),
               let result = data["result"] {
                _ = try await SupabaseService.shared.logLHTest(
                    cycleId: cycleId,
                    date: Date(),
                    result: result
                )
            }
            
        case .updateNotificationSettings:
            if let data = operation.data {
                var update = ProfileUpdate()
                if let tone = data["notificationTone"] {
                    update.notificationTone = tone
                }
                if let enabled = data["notificationsEnabled"] {
                    update.notificationsEnabled = enabled == "true"
                }
                _ = try await SupabaseService.shared.updateProfile(update)
            }
            
        case .createCycle:
            if let data = operation.data,
               let startDateString = data["startDate"],
               let startDate = ISO8601DateFormatter().date(from: startDateString),
               let cycleLengthString = data["cycleLength"],
               let cycleLength = Int(cycleLengthString) {
                _ = try await SupabaseService.shared.createCycle(
                    startDate: startDate,
                    cycleLength: cycleLength
                )
            }
            
        case .logIntimacy:
            if let data = operation.data,
               let dateString = data["date"],
               let date = ISO8601DateFormatter().date(from: dateString),
               let hadIntimacyString = data["hadIntimacy"] {
                try await SupabaseService.shared.logIntimacy(
                    date: date,
                    hadIntimacy: hadIntimacyString == "true"
                )
            }
        }
    }
    
    // MARK: - Persistence
    
    private func savePendingOperations() {
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: operationsKey)
        }
    }
    
    private func loadPendingOperations() {
        if let data = UserDefaults.standard.data(forKey: operationsKey),
           let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) {
            pendingOperations = operations
        }
    }
    
    /// Get count of pending operations
    var pendingCount: Int {
        pendingOperations.count
    }
    
    /// Clear all pending operations
    func clearPendingOperations() {
        pendingOperations.removeAll()
        savePendingOperations()
    }
}

// MARK: - Supporting Types

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
}

enum NetworkError: LocalizedError {
    case noConnection
    case maxRetriesExceeded
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .maxRetriesExceeded:
            return "Failed after multiple attempts"
        case .timeout:
            return "Request timed out"
        }
    }
}

struct PendingOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let data: [String: String]?
    let createdAt: Date
    
    init(type: OperationType, data: [String: String]? = nil) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.createdAt = Date()
    }
}

enum OperationType: String, Codable {
    case updateProfile
    case logLHTest
    case updateNotificationSettings
    case createCycle
    case logIntimacy
}
