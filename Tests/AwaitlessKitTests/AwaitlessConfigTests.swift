//
// Copyright (c) 2025 Daniel Bauke
//

@testable import AwaitlessKit
import AwaitlessKitMacros
import MacroTesting
import Testing

@Suite(.macros(["AwaitlessConfig": AwaitlessConfigMacro.self], record: .missing))
struct AwaitlessConfigTests {
    
    @Test("Basic @AwaitlessConfig macro expansion")
    func basicConfigMacro() {
        assertMacro {
            """
            @AwaitlessConfig(prefix: "sync")
            class DataService {
                func processData() async throws -> String { "test" }
            }
            """
        } expansion: {
            """
            class DataService {
                func processData() async throws -> String { "test" }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData(prefix: "sync")
            }
            """
        }
    }
    
    @Test("@AwaitlessConfig with multiple parameters")
    func multipleParametersConfigMacro() {
        assertMacro {
            """
            @AwaitlessConfig(prefix: "legacy", availability: .deprecated("Use async version"))
            struct APIClient {
                func fetchData() async -> Data { Data() }
            }
            """
        } expansion: {
            """
            struct APIClient {
                func fetchData() async -> Data { Data() }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData(prefix: "legacy", availability: AwaitlessAvailability.deprecated("Use async version"))
            }
            """
        }
    }
    
    @Test("@AwaitlessConfig with delivery parameter")
    func deliveryParameterConfigMacro() {
        assertMacro {
            """
            @AwaitlessConfig(delivery: .main)
            actor EventService {
                func processEvents() async { }
            }
            """
        } expansion: {
            """
            actor EventService {
                func processEvents() async { }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData(delivery: AwaitlessDelivery.main)
            }
            """
        }
    }
    
    @Test("@AwaitlessConfig with all parameters")
    func allParametersConfigMacro() {
        assertMacro {
            """
            @AwaitlessConfig(
                prefix: "sync",
                availability: .unavailable("Not supported"),
                delivery: .current,
                strategy: .serial
            )
            class CompleteService {
                func doWork() async { }
            }
            """
        } expansion: {
            """
            class CompleteService {
                func doWork() async { }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData(prefix: "sync", availability: AwaitlessAvailability.unavailable("Not supported"), delivery: AwaitlessDelivery.current, strategy: AwaitlessSynchronizationStrategy.serial)
            }
            """
        }
    }
    
    @Test("@AwaitlessConfig with empty parameters")
    func emptyParametersConfigMacro() {
        assertMacro {
            """
            @AwaitlessConfig()
            class EmptyConfigService {
                func work() async { }
            }
            """
        } expansion: {
            """
            class EmptyConfigService {
                func work() async { }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData()
            }
            """
        }
    }
}

@Suite("AwaitlessConfig API Tests")
struct AwaitlessConfigAPITests {
    
    @Test("AwaitlessConfig.setDefaults and currentDefaults")
    @MainActor
    func configDefaults() async {
        // Test initial state
        let initialDefaults = AwaitlessConfig.currentDefaults
        #expect(initialDefaults.prefix == nil)
        #expect(initialDefaults.availability == nil)
        #expect(initialDefaults.delivery == nil)
        #expect(initialDefaults.strategy == nil)
        
        // Set new defaults
        AwaitlessConfig.setDefaults(
            prefix: "sync",
            availability: .deprecated("Use async version"),
            delivery: .main,
            strategy: .concurrent
        )
        
        // Verify defaults were set
        let newDefaults = AwaitlessConfig.currentDefaults
        #expect(newDefaults.prefix == "sync")
        // Note: We can't easily test enum equality here without implementing Equatable
        #expect(newDefaults.availability != nil)
        #expect(newDefaults.delivery != nil)
        #expect(newDefaults.strategy != nil)
        
        // Reset defaults for other tests
        AwaitlessConfig.setDefaults()
    }
    
    @Test("AwaitlessConfig.setDefaults with partial parameters")
    @MainActor
    func partialConfigDefaults() async {
        // Set only prefix
        AwaitlessConfig.setDefaults(prefix: "legacy")
        
        let defaults = AwaitlessConfig.currentDefaults
        #expect(defaults.prefix == "legacy")
        #expect(defaults.availability == nil)
        #expect(defaults.delivery == nil)
        #expect(defaults.strategy == nil)
        
        // Reset
        AwaitlessConfig.setDefaults()
    }
}

@Suite("Configuration Hierarchy Integration Tests", .macros([
    "AwaitlessConfig": AwaitlessConfigMacro.self,
    "Awaitless": AwaitlessSyncMacro.self
], record: .missing))
struct AwaitlessConfigurationHierarchyTests {
    
    @Test("Method-level prefix works correctly")
    func methodLevelPrefixWorks() {
        assertMacro {
            """
            @AwaitlessConfig(prefix: "sync")
            class DataService {
                @Awaitless(prefix: "custom")
                func fetchData() async throws -> String { "test" }
            }
            """
        } expansion: {
            """
            class DataService {
                func fetchData() async throws -> String { "test" }
            
                @available(*, noasync) func customfetchData() throws -> String {
                    try Noasync.run({
                            try await fetchData()
                        })
                }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData(prefix: "sync")
            }
            """
        }
    }
    
    @Test("Type-level configuration generates properly")  
    func typeLevelConfigurationGenerates() {
        assertMacro {
            """
            @AwaitlessConfig(prefix: "sync")
            class DataService {
                @Awaitless
                func processData() async throws -> String { "test" }
            }
            """
        } expansion: {
            """
            class DataService {
                func processData() async throws -> String { "test" }
            
                @available(*, noasync) func processData() throws -> String {
                    try Noasync.run({
                            try await processData()
                        })
                }
            
                static let __awaitlessConfig: AwaitlessConfigData = AwaitlessConfigData(prefix: "sync")
            }
            """
        }
    }
}