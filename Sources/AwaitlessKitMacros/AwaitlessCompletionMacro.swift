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

// MARK: - AwaitlessCompletionMacro

/// A macro that generates a completion-handler version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function and calls a completion handler with the result.
public struct AwaitlessCompletionMacro: PeerMacro {
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
                message: AwaitlessCompletionMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(
                node: diagnosticNode,
                message: AwaitlessCompletionMacroDiagnostic.requiresAsync)
            context.diagnose(diagnostic)
            return []
        }

        // Extract prefix and availability from the attribute
        var prefix = ""
        var availability: AwaitlessAvailability? = nil

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
            }

            // Check for availability parameter (first unlabeled argument or argument without specific label)
            for argument in arguments {
                if argument.label?.text != "prefix",
                   let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @AwaitlessCompletion(.deprecated) or @AwaitlessCompletion(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if argument.label?.text != "prefix",
                          let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
                          let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @AwaitlessCompletion(.deprecated("message")) or @AwaitlessCompletion(.unavailable("message"))
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

        // Create the completion function
        let generatedDecl: DeclSyntax = DeclSyntax(AwaitlessMacroHelpers.createCompletionFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability))
        return [generatedDecl]
    }
}

// MARK: - AwaitlessCompletionMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessCompletion macro
enum AwaitlessCompletionMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitlessCompletion can only be applied to functions"
    case requiresAsync = "@AwaitlessCompletion requires the function to be 'async'"

    var severity: DiagnosticSeverity {
        return .error
    }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}