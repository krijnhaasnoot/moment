//
//  NetworkServiceTests.swift
//  MomentTests
//
//  Tests for network service, offline mode, and retry logic
//

import Testing
import Foundation
@testable import Moment

@Suite("Network Service Tests")
struct NetworkServiceTests {
    
    // MARK: - Retry Logic Tests
    
    @Test("Retry logic respects max attempts")
    func retryRespectsMaxAttempts() async {
        var attemptCount = 0
        let maxAttempts = 3
        
        do {
            _ = try await NetworkService.shared.withRetry(maxAttempts: maxAttempts, delay: 0.01) {
                attemptCount += 1
                throw NetworkError.timeout
            }
        } catch {
            // Expected to fail
        }
        
        #expect(attemptCount == maxAttempts)
    }
    
    @Test("Retry succeeds on second attempt")
    func retrySucceedsOnSecondAttempt() async throws {
        var attemptCount = 0
        
        let result = try await NetworkService.shared.withRetry(maxAttempts: 3, delay: 0.01) {
            attemptCount += 1
            if attemptCount < 2 {
                throw NetworkError.timeout
            }
            return "success"
        }
        
        #expect(result == "success")
        #expect(attemptCount == 2)
    }
    
    @Test("Retry returns immediately on success")
    func retryReturnsImmediatelyOnSuccess() async throws {
        var attemptCount = 0
        
        let result = try await NetworkService.shared.withRetry(maxAttempts: 3, delay: 0.01) {
            attemptCount += 1
            return 42
        }
        
        #expect(result == 42)
        #expect(attemptCount == 1)
    }
    
    // MARK: - Pending Operation Tests
    
    @Test("Pending operation creation")
    func pendingOperationCreation() {
        let operation = PendingOperation(
            type: .updateProfile,
            data: ["name": "Test"]
        )
        
        #expect(operation.type == .updateProfile)
        #expect(operation.data?["name"] == "Test")
    }
    
    @Test("Pending operation types")
    func pendingOperationTypes() {
        let types: [OperationType] = [.updateProfile, .logLHTest, .updateNotificationSettings]
        #expect(types.count == 3)
    }
    
    @Test("Operation is encodable and decodable")
    func operationCodable() throws {
        let original = PendingOperation(
            type: .updateNotificationSettings,
            data: ["notificationsEnabled": "true"]
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PendingOperation.self, from: encoded)
        
        #expect(decoded.type == original.type)
        #expect(decoded.data?["notificationsEnabled"] == "true")
    }
    
    // MARK: - Connection Type Tests
    
    @Test("Connection types are distinct")
    func connectionTypesDistinct() {
        let types: [ConnectionType] = [.wifi, .cellular, .ethernet, .unknown]
        let uniqueTypes = Set(types.map { String(describing: $0) })
        #expect(uniqueTypes.count == 4)
    }
    
    // MARK: - Network Error Tests
    
    @Test("Network errors have descriptions")
    func networkErrorDescriptions() {
        let errors: [NetworkError] = [.noConnection, .maxRetriesExceeded, .timeout]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("No connection error message")
    func noConnectionErrorMessage() {
        let error = NetworkError.noConnection
        #expect(error.errorDescription?.lowercased().contains("connection") == true)
    }
    
    @Test("Max retries error message")
    func maxRetriesErrorMessage() {
        let error = NetworkError.maxRetriesExceeded
        #expect(error.errorDescription?.lowercased().contains("attempt") == true)
    }
    
    @Test("Timeout error message")
    func timeoutErrorMessage() {
        let error = NetworkError.timeout
        #expect(error.errorDescription?.lowercased().contains("timed out") == true)
    }
}

@Suite("Offline Queue Tests")
struct OfflineQueueTests {
    
    @Test("Queue operation increments count")
    func queueOperationIncrementsCount() {
        let service = NetworkService.shared
        let initialCount = service.pendingCount
        
        service.queueOperation(PendingOperation(type: .updateProfile, data: ["test": "value"]))
        
        #expect(service.pendingCount == initialCount + 1)
        
        // Cleanup
        service.clearPendingOperations()
    }
    
    @Test("Clear operations resets count")
    func clearOperationsResetsCount() {
        let service = NetworkService.shared
        
        service.queueOperation(PendingOperation(type: .updateProfile))
        service.queueOperation(PendingOperation(type: .logLHTest))
        service.clearPendingOperations()
        
        #expect(service.pendingCount == 0)
    }
    
    @Test("Pending operation stores data correctly")
    func pendingOperationStoresData() {
        let data = ["name": "Test User", "value": "42"]
        let operation = PendingOperation(type: .updateProfile, data: data)
        
        #expect(operation.data?["name"] == "Test User")
        #expect(operation.data?["value"] == "42")
    }
    
    @Test("Operation type raw values")
    func operationTypeRawValues() {
        #expect(OperationType.updateProfile.rawValue == "updateProfile")
        #expect(OperationType.logLHTest.rawValue == "logLHTest")
        #expect(OperationType.updateNotificationSettings.rawValue == "updateNotificationSettings")
    }
}
