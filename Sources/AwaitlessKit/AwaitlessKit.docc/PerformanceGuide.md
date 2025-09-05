# Performance Guide

Optimize performance when using AwaitlessKit macros for sync/async code generation.

## Overview

AwaitlessKit generates synchronous wrappers that internally use blocking calls to async functions. Understanding the performance characteristics and optimization strategies is crucial for production use.

## Performance Characteristics

### Blocking Behavior

Generated sync wrappers block the calling thread:

```swift
@Awaitless
func fetchData() async throws -> Data {
    // Network operation taking 100ms
    try await URLSession.shared.data(from: url)
}

// Generated wrapper blocks for 100ms
let data = try fetchData()  // Thread blocked until completion
```

### Thread Pool Impact

Sync wrappers use thread pool resources:

```swift
// ❌ Can exhaust thread pool
for i in 0..<1000 {
    Task.detached {
        let data = try fetchData()  // Each call blocks a thread
        process(data)
    }
}

// ✅ Better: Use async versions in concurrent contexts
for i in 0..<1000 {
    Task.detached {
        let data = try await fetchData()  // Non-blocking
        process(data)
    }
}
```

### Memory Overhead

Each sync wrapper call creates additional stack frames:

```swift
// Stack depth for sync wrapper:
// 1. Your calling code
// 2. Generated wrapper function
// 3. Noasync.run execution
// 4. RunLoop blocking
// 5. Original async function

// Stack depth for direct async:
// 1. Your calling code  
// 2. Original async function (suspended, minimal stack)
```

## Performance Optimization

### Strategy 1: Minimize Wrapper Depth

Avoid deep chains of sync wrapper calls:

```swift
// ❌ Multiple wrapper levels
func processUser() -> User {
    let data = fetchUserData()      // Wrapper 1
    let profile = fetchProfile()    // Wrapper 2  
    let settings = fetchSettings()  // Wrapper 3
    return combineData(data, profile, settings)
}

// ✅ Single wrapper at boundary
@Awaitless
func processUserAsync() async throws -> User {
    async let data = fetchUserData()     // Direct async
    async let profile = fetchProfile()   // Direct async
    async let settings = fetchSettings() // Direct async
    return try await combineData(data, profile, settings)
}

// Single wrapper call from sync context
let user = try processUserAsync()
```

### Strategy 2: Batch Operations

Group multiple async operations into single wrappers:

```swift
// ❌ Multiple individual wrapper calls
func loadDashboard() -> Dashboard {
    let users = try fetchUsers()           // Blocks 50ms
    let posts = try fetchPosts()           // Blocks 30ms  
    let notifications = try fetchNotifications() // Blocks 20ms
    return Dashboard(users: users, posts: posts, notifications: notifications)
}
// Total: 100ms sequential

// ✅ Single wrapper for concurrent operations
@Awaitless
func loadDashboardData() async throws -> Dashboard {
    async let users = fetchUsers()
    async let posts = fetchPosts()
    async let notifications = fetchNotifications()
    
    return try await Dashboard(
        users: users,
        posts: posts, 
        notifications: notifications
    )
}
// Total: 50ms concurrent (limited by slowest operation)
```

### Strategy 3: Smart Configuration

Use configuration to optimize for specific use cases:

```swift
// For CPU-bound operations: use global queue
@AwaitlessConfig(delivery: .global(qos: .userInitiated))
class CPUIntensiveService {
    @AwaitlessPublisher
    func processLargeDataset() async throws -> [ProcessedItem] {
        // CPU-intensive work
    }
}

// For UI updates: use main queue
@AwaitlessConfig(delivery: .main)
class UIUpdateService {
    @AwaitlessPublisher
    func fetchUserInterface() async throws -> UIData {
        // UI-related data fetching
    }
}
```

## Performance Monitoring

### Metrics to Track

Monitor these key performance indicators:

1. **Thread Pool Utilization** - Percentage of threads blocked by sync wrappers
2. **Response Time Distribution** - P50, P95, P99 latencies for wrapper calls
3. **Memory Usage** - Stack depth and heap allocation patterns
4. **Concurrency Levels** - Number of concurrent sync wrapper calls
5. **Error Rates** - Timeouts and failures in blocking operations

### Instrumentation Example

```swift
class PerformanceMonitor {
    static func measureSyncWrapper<T>(
        operation: String,
        block: () throws -> T
    ) rethrows -> T {
        let start = DispatchTime.now()
        let threadsBefore = Thread.activeCount
        
        defer {
            let end = DispatchTime.now()
            let duration = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
            let threadsAfter = Thread.activeCount
            
            logger.info("Sync wrapper: \(operation) took \(duration)ms, threads: \(threadsBefore)→\(threadsAfter)")
        }
        
        return try block()
    }
}

// Usage in generated wrappers
func fetchData() throws -> Data {
    return PerformanceMonitor.measureSyncWrapper(operation: "fetchData") {
        return Noasync.run {
            try await fetchData()
        }
    }
}
```

### Performance Testing

Create performance tests for critical paths:

```swift
class SyncWrapperPerformanceTests: XCTestCase {
    func testConcurrentWrapperCalls() {
        let expectation = XCTestExpectation(description: "Concurrent calls")
        expectation.expectedFulfillmentCount = 100
        
        let start = DispatchTime.now()
        
        // Test 100 concurrent sync wrapper calls
        for _ in 0..<100 {
            DispatchQueue.global().async {
                _ = try! service.fetchData()  // Sync wrapper
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        let end = DispatchTime.now()
        let duration = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        
        XCTAssertLessThan(duration, 5.0, "Concurrent wrapper calls took too long")
    }
    
    func testWrapperVsAsyncPerformance() async {
        let iterations = 1000
        
        // Measure sync wrapper performance
        let syncStart = DispatchTime.now()
        for _ in 0..<iterations {
            _ = try! service.quickOperation()  // Sync wrapper
        }
        let syncEnd = DispatchTime.now()
        let syncDuration = Double(syncEnd.uptimeNanoseconds - syncStart.uptimeNanoseconds) / 1_000_000_000
        
        // Measure async performance
        let asyncStart = DispatchTime.now()
        for _ in 0..<iterations {
            _ = try! await service.quickOperation()  // Direct async
        }
        let asyncEnd = DispatchTime.now()
        let asyncDuration = Double(asyncEnd.uptimeNanoseconds - asyncStart.uptimeNanoseconds) / 1_000_000_000
        
        // Wrapper should be within 2x of async performance
        let overhead = syncDuration / asyncDuration
        XCTAssertLessThan(overhead, 2.0, "Sync wrapper overhead too high: \(overhead)x")
    }
}
```

## Scaling Considerations

### Thread Pool Sizing

Configure appropriate thread pool sizes for your workload:

```swift
// For applications with many sync wrapper calls
let customQueue = DispatchQueue(
    label: "sync-wrapper-queue",
    qos: .userInitiated,
    attributes: .concurrent,
    autoreleaseFrequency: .workItem,
    target: nil
)

// Use custom queue for wrapper execution
extension Noasync {
    static func runOnCustomQueue<T>(operation: () async throws -> T) rethrows -> T {
        // Custom implementation using specific queue
    }
}
```

### Load Balancing

Distribute sync wrapper calls across multiple execution contexts:

```swift
class LoadBalancedService {
    private let executors: [ExecutorService]
    private var currentIndex = 0
    
    @Awaitless
    func processRequest() async throws -> Response {
        let executor = nextExecutor()
        return try await executor.process()
    }
    
    private func nextExecutor() -> ExecutorService {
        defer { currentIndex = (currentIndex + 1) % executors.count }
        return executors[currentIndex]
    }
}
```

### Memory Management

Optimize memory usage in high-throughput scenarios:

```swift
// Use autoreleasepool for memory-intensive operations
@Awaitless
func processLargeDataset() async throws -> ProcessedData {
    return try await autoreleasepool {
        // Memory-intensive processing
        let processed = try await heavyComputation()
        return processed
    }
}
```

## Anti-Patterns

### Anti-Pattern 1: Blocking UI Thread

```swift
// ❌ Never block the main thread
@IBAction func buttonTapped(_ sender: UIButton) {
    let data = try! networkService.fetchData()  // Blocks UI!
    updateUI(with: data)
}

// ✅ Use async patterns or background queues
@IBAction func buttonTapped(_ sender: UIButton) {
    Task {
        let data = try await networkService.fetchData()
        await MainActor.run {
            updateUI(with: data)
        }
    }
}
```

### Anti-Pattern 2: Recursive Wrapper Calls

```swift
// ❌ Avoid recursion with sync wrappers
func recursiveProcess(depth: Int) -> Result {
    if depth == 0 { return .base }
    let intermediate = processStep()  // Sync wrapper
    return recursiveProcess(depth: depth - 1)  // Stack buildup
}

// ✅ Use async recursion
@Awaitless
func recursiveProcessAsync(depth: Int) async -> Result {
    if depth == 0 { return .base }
    let intermediate = await processStep()
    return await recursiveProcessAsync(depth: depth - 1)
}
```

### Anti-Pattern 3: Sync Wrapper in Performance-Critical Loops

```swift
// ❌ Avoid wrappers in tight loops
func processAllItems(_ items: [Item]) -> [ProcessedItem] {
    return items.map { item in
        return processItem(item)  // Sync wrapper in loop
    }
}

// ✅ Batch process or use async sequences
@Awaitless
func processAllItemsAsync(_ items: [Item]) async -> [ProcessedItem] {
    var results: [ProcessedItem] = []
    for item in items {
        let processed = await processItem(item)  // Direct async
        results.append(processed)
    }
    return results
}
```

## Production Recommendations

### Deployment Checklist

Before deploying sync wrappers to production:

1. **Performance Benchmarks** - Establish baseline performance metrics
2. **Load Testing** - Test under expected concurrent load
3. **Thread Pool Monitoring** - Ensure adequate thread pool capacity
4. **Timeout Configuration** - Set appropriate timeouts for all operations
5. **Circuit Breakers** - Implement failure protection mechanisms
6. **Gradual Rollout** - Use feature flags for controlled deployment

### Monitoring in Production

Set up comprehensive monitoring:

```swift
// Production monitoring integration
extension Noasync {
    static func runWithMetrics<T>(
        operation: String,
        timeout: TimeInterval = 30.0,
        block: () async throws -> T
    ) rethrows -> T {
        let start = DispatchTime.now()
        
        defer {
            let duration = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
            
            // Send metrics to monitoring system
            Metrics.timer("sync_wrapper.duration")
                .tag("operation", operation)
                .record(duration)
                
            Metrics.counter("sync_wrapper.calls")
                .tag("operation", operation)
                .increment()
        }
        
        return try block()
    }
}
```

### Configuration for Production

Optimize configuration for production workloads:

```swift
// Production configuration
AwaitlessConfig.setDefaults(
    prefix: "",  // No prefix for cleaner APIs
    availability: .deprecated("Migrate to async by 2025-Q1"),  // Clear migration timeline
    delivery: .global(qos: .userInitiated),  // Appropriate QoS
    strategy: .concurrent  // Better performance for most workloads
)

// Critical path optimization
@AwaitlessConfig(delivery: .current)  // Minimize queue hopping
class CriticalPathService {
    @Awaitless
    func performCriticalOperation() async throws -> CriticalResult {
        // High-performance implementation
    }
}
```

By following these performance guidelines, you can effectively use AwaitlessKit in production while maintaining optimal performance characteristics.