//
// Copyright (c) 2025 Daniel Bauke
//
// Portions adapted from a Swift Forums discussion:
// "How to correctly convert from an async function to Combine or any other framework"
// https://forums.swift.org/t/how-to-correctly-convert-from-an-async-function-to-combine-or-any-other-framework/64009/2
//

#if canImport(Combine)
public import Combine
import Foundation

// MARK: - Throwing Task-backed Publisher (internal)

@usableFromInline struct AwaitlessTaskThrowingPublisher<Output: Sendable>: Publisher {
    @usableFromInline typealias Failure = Error

    private let priority: TaskPriority
    private let work: @Sendable () async throws -> Output

    @usableFromInline init(
        priority: TaskPriority = .medium,
        work: @escaping @Sendable () async throws -> Output
    ) {
        self.priority = priority
        self.work = work
    }

    @usableFromInline func receive<S: Subscriber>(subscriber: S)
        where S.Input == Output, S.Failure == Failure
    {
        let subscription = ThrowingTaskSubscription(
            priority: priority,
            work: work,
            subscriber: subscriber
        )
        subscriber.receive(subscription: subscription)
        subscription.start()
    }

    private final class ThrowingTaskSubscription<Downstream: Subscriber>: Combine.Subscription, @unchecked Sendable
        where Downstream.Input == Output, Downstream.Failure == Error
    {
        private var handle: Task<Output, Error>?
        private let priority: TaskPriority
        private let work: @Sendable () async throws -> Output
        private var downstream: Downstream?

        init(
            priority: TaskPriority,
            work: @escaping @Sendable () async throws -> Output,
            subscriber: Downstream
        ) {
            self.priority = priority
            self.work = work
            self.downstream = subscriber
        }

        func start() {
            guard handle == nil else { return }
            handle = Task(priority: priority) { [self] in
                do {
                    let result = try await work()
                    try Task.checkCancellation()
                    if let downstream {
                        _ = downstream.receive(result)
                        downstream.receive(completion: .finished)
                    }
                    return result
                } catch {
                    if let downstream {
                        downstream.receive(completion: .failure(error))
                    }
                    throw error
                }
            }
        }

        func request(_ demand: Subscribers.Demand) {
            // Single-shot publisher; demand is not used.
        }

        func cancel() {
            handle?.cancel()
            downstream = nil
        }
    }
}

// MARK: - Non-throwing Task-backed Publisher (internal)

@usableFromInline struct AwaitlessTaskPublisher<Output: Sendable>: Publisher {
    @usableFromInline typealias Failure = Never

    private let priority: TaskPriority
    private let work: @Sendable () async -> Output

    @usableFromInline init(
        priority: TaskPriority = .medium,
        work: @escaping @Sendable () async -> Output
    ) {
        self.priority = priority
        self.work = work
    }

    @usableFromInline func receive<S: Subscriber>(subscriber: S)
        where S.Input == Output, S.Failure == Failure
    {
        let subscription = NonThrowingTaskSubscription(
            priority: priority,
            work: work,
            subscriber: subscriber
        )
        subscriber.receive(subscription: subscription)
        subscription.start()
    }

    private final class NonThrowingTaskSubscription<Downstream: Subscriber>: Combine.Subscription, @unchecked Sendable
        where Downstream.Input == Output, Downstream.Failure == Never
    {
        private var handle: Task<Output, Never>?
        private let priority: TaskPriority
        private let work: @Sendable () async -> Output
        private var downstream: Downstream?

        init(
            priority: TaskPriority,
            work: @escaping @Sendable () async -> Output,
            subscriber: Downstream
        ) {
            self.priority = priority
            self.work = work
            self.downstream = subscriber
        }

        func start() {
            guard handle == nil else { return }
            handle = Task(priority: priority) { [self] in
                let value = await work()
                if let downstream {
                    _ = downstream.receive(value)
                    downstream.receive(completion: .finished)
                }
                return value
            }
        }

        func request(_ demand: Subscribers.Demand) {
            // Single-shot publisher; demand is not used.
        }

        func cancel() {
            handle?.cancel()
            downstream = nil
        }
    }
}

// MARK: - Factory used by macro-generated code

public enum AwaitlessCombineFactory {
    public static func makeThrowing<Output: Sendable>(
        priority: TaskPriority = .medium,
        work: @escaping @Sendable () async throws -> Output
    ) -> AnyPublisher<Output, Error> {
        AwaitlessTaskThrowingPublisher(priority: priority, work: work)
            .eraseToAnyPublisher()
    }

    public static func makeNonThrowing<Output: Sendable>(
        priority: TaskPriority = .medium,
        work: @escaping @Sendable () async -> Output
    ) -> AnyPublisher<Output, Never> {
        AwaitlessTaskPublisher(priority: priority, work: work)
            .eraseToAnyPublisher()
    }
}

#endif
