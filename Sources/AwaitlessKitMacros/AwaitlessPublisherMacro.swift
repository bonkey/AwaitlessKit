//
// Copyright (c) 2025 Daniel Bauke
//

public import SwiftSyntax
public import SwiftSyntaxMacros
import AwaitlessCore
import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntaxBuilder
#if canImport(Combine)
import Combine
#endif

// MARK: - AwaitlessPublisherMacro

/// A macro that generates a Combine publisher version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function in a Future publisher, making it consumable via Combine.
public struct AwaitlessPublisherMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        // Handle protocol declarations
        if declaration.is(ProtocolDeclSyntax.self) {
            return [] // Protocols are handled by MemberMacro
        }
        
        // Handle function declarations (existing behavior)
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitlessPublisherMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // For @AwaitlessPublisher, we relax the async check because publisher code can wrap both async and non-async functions.
        // The generated publisher will call the original function, regardless of its async-ness.

        // Extract prefix, availability, and delivery from the attribute
        var prefix = ""
        var availability: AwaitlessAvailability? = nil
        var delivery: AwaitlessDelivery = .current

        if case let .argumentList(arguments) = node.arguments {
            // Check for prefix parameter
            for argument in arguments {
                let labeledExpr = argument
                if labeledExpr.label?.text == "prefix",
                   let stringLiteral = labeledExpr.expression.as(StringLiteralExprSyntax.self)
                {
                    // Extract prefix from the string literal
                    prefix = stringLiteral.segments.description
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }

                // Parse delivery option for @AwaitlessPublisher
                if labeledExpr.label?.text == "deliverOn",
                   let memberAccess = labeledExpr.expression.as(MemberAccessExprSyntax.self)
                {
                    if memberAccess.declName.baseName.text == "main" {
                        delivery = .main
                    } else {
                        delivery = .current
                    }
                }
            }

            // Check for availability parameter (first unlabeled argument or argument without specific label)
            for argument in arguments {
                if argument.label?.text != "prefix" && argument.label?.text != "deliverOn",
                   let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @AwaitlessPublisher(.deprecated) or @AwaitlessPublisher(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if argument.label?.text != "prefix" && argument.label?.text != "deliverOn",
                          let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
                          let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @AwaitlessPublisher(.deprecated("message")) or @AwaitlessPublisher(.unavailable("message"))
                    if calledExpr.declName.baseName.text == "deprecated" {
                        if let firstArgument = functionCall.arguments.first?.expression
                            .as(StringLiteralExprSyntax.self)
                        {
                            let message = firstArgument.segments.description
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            availability = .deprecated(message)
                        } else {
                            availability = .deprecated()
                        }
                    } else if calledExpr.declName.baseName.text == "unavailable" {
                        if let firstArgument = functionCall.arguments.first?.expression
                            .as(StringLiteralExprSyntax.self)
                        {
                            let message = firstArgument.segments.description
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            availability = .unavailable(message)
                        } else {
                            availability = .unavailable()
                        }
                    }
                }
            }
        }

        // Create the publisher function
        #if canImport(Combine)
        let generatedDecl: DeclSyntax = DeclSyntax(AwaitlessMacroHelpers.createPublisherFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability,
            delivery: delivery))
        return [generatedDecl]
        #else
        let diagnostic = Diagnostic(
            node: Syntax(declaration),
            message: AwaitlessPublisherMacroDiagnostic.combineNotAvailable)
        context.diagnose(diagnostic)
        return []
        #endif
    }
}

// MARK: - AwaitlessPublisherMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessPublisher macro
enum AwaitlessPublisherMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitlessPublisher can only be applied to functions"
    case combineNotAvailable = "@AwaitlessPublisher requires Combine framework, which is not available on this platform"

    var severity: DiagnosticSeverity {
        return .error
    }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}