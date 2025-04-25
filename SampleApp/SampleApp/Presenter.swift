//
//  DataPresenter.swift
//  SampleApp
//
//  Created by Daniel Bauke on 25.04.25.
//

import AwaitlessKit
import Foundation

final class Presenter: Sendable {
    private let dataProcessor = DataProcessor()
    
    func run() throws {
        accessIsolatedSafeProperty()
        executeWithAwaitlessMacro()
        try processWithAwaitlessThrowingFunction()
        processWithAwaitlessNonThrowingFunction()
    }
    
    private func accessIsolatedSafeProperty() {
        for string in dataProcessor.strings {
            print(string)
        }
    }
    
    private func executeWithAwaitlessMacro() {
        #awaitless(dataProcessor.asyncFunctionWithAwaitlessDeprecated())
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
