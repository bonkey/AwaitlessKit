//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessKit
import Foundation

final class Presenter: Sendable {
    func run() throws {
        accessIsolatedSafeProperty()
        executeWithAwaitlessMacro()
        try processWithAwaitlessThrowingFunction()
        processWithAwaitlessNonThrowingFunction()

//      WIP: withCompletion()
    }

    private let dataProcessor = DataProcessor()

    private func accessIsolatedSafeProperty() {
        for string in dataProcessor.strings {
            print(string)
        }
    }

    private func executeWithAwaitlessMacro() {
        #awaitless(dataProcessor.asyncFunctionWithAwaitlessDeprecated())
    }

    private func withCompletion() {
        Noasync.withCompletion(dataProcessor.custom_asyncThrowingFunction) { (result: Result<String, Error>) in
            switch result {
            case let .failure(error):
                print("Error: \(error)")
            case let .success(value):
                print(value)
            }
        }
    }

    private func processWithAwaitlessThrowingFunction() throws {
        try print(dataProcessor.awaitless_asyncThrowingFunctionWithAwaitlessCustomPrefix())
        try print(dataProcessor.custom_asyncThrowingFunction())
    }

    private func processWithAwaitlessNonThrowingFunction() {
        print(dataProcessor.asyncFunctionWithAwaitlessDefault())
        print(#awaitless(dataProcessor.asyncFunctionWithAwaitlessDefault()))
    }
}
