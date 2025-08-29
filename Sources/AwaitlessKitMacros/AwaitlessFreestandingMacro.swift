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

// MARK: - AwaitlessFreestandingMacro

/// A freestanding macro that wraps an expression with Noasync.run
/// Usage: #awaitless(someAsyncFunction())
public struct AwaitlessFreestandingMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext) throws
        -> ExprSyntax
    {
        // Get the expression to wrap with Noasync.run
        guard let argument = node.arguments.first?.expression else {
            let diagnostic = Diagnostic(
                node: Syntax(node),
                message: AwaitlessFreestandingMacroDiagnostic.missingArgument)
            context.diagnose(diagnostic)
            return ExprSyntax(stringLiteral: "/* Error: Missing argument */")
        }

        // Extract the actual expression if it's wrapped in a TryExpr
        var actualExpression = argument
        var hasTry = false
        if let tryExpr = argument.as(TryExprSyntax.self) {
            actualExpression = tryExpr.expression
            hasTry = true
        }

        // Prepare the expression with await and try if needed
        let awaitExpr = ExprSyntax(AwaitExprSyntax(
            expression: actualExpression))

        let finalExpr = hasTry ?
            ExprSyntax(TryExprSyntax(expression: awaitExpr)) :
            awaitExpr

        // Create a closure that returns the result of the expression
        let closure = ExprSyntax(
            ClosureExprSyntax(
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(item: .stmt(
                        StmtSyntax(
                            ReturnStmtSyntax(
                                returnKeyword: .keyword(.return, trailingTrivia: .space),
                                expression: finalExpr))))
                }))

        // Create the Noasync.run call with the closure and return the result directly
        return ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("Noasync")),
                    period: .periodToken(),
                    name: .identifier("run")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(expression: closure)
                },
                rightParen: .rightParenToken()))
    }


}

// MARK: - AwaitlessFreestandingMacroDiagnostic

/// Diagnostics for the Awaitless macro
enum AwaitlessFreestandingMacroDiagnostic: String, DiagnosticMessage {
    case missingArgument = "#awaitless requires an expression argument"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessFreestandingMacro", id: rawValue)
    }
}
