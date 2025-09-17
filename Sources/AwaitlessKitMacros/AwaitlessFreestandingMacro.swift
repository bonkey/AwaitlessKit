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

/// A freestanding macro that wraps an expression with Awaitless.run
/// Usage: #awaitless(someAsyncFunction())
public struct AwaitlessFreestandingMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext) throws
        -> ExprSyntax
    {
        // Get the expression to wrap with Awaitless.run
        guard let argument = node.arguments.first?.expression else {
            let diagnostic = Diagnostic(
                node: Syntax(node),
                message: AwaitlessFreestandingMacroDiagnostic.missingArgument)
            context.diagnose(diagnostic)
            return ExprSyntax(stringLiteral: "/* Error: Missing argument */")
        }

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

        // For simple expressions, use a single statement without return
        // For complex expressions, use a return statement
        let isSimpleExpression: Bool = {
            if let funcCall = actualExpression.as(FunctionCallExprSyntax.self) {
                // Function calls with trailing closures or complex arguments are not simple
                return funcCall.trailingClosure == nil && 
                       !funcCall.arguments.contains { arg in
                           arg.expression.is(ClosureExprSyntax.self)
                       }
            }
            return actualExpression.is(DeclReferenceExprSyntax.self) ||
                   actualExpression.is(MemberAccessExprSyntax.self)
        }()
        
        let closure: ClosureExprSyntax
        if isSimpleExpression {
            // Simple single-line closure for basic function calls - no newlines
            closure = ClosureExprSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(item: .expr(finalExpr), trailingTrivia: .space)
                },
                rightBrace: .rightBraceToken()
            )
        } else {
            // Multi-line closure with return statement for complex expressions
            closure = ClosureExprSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(item: .stmt(
                        StmtSyntax(
                            ReturnStmtSyntax(
                                returnKeyword: .keyword(.return, trailingTrivia: .space),
                                expression: finalExpr))))
                },
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        }

        return ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("Awaitless")),
                    period: .periodToken(),
                    name: .identifier("run")),
                leftParen: nil,
                arguments: LabeledExprListSyntax([]),
                rightParen: nil,
                trailingClosure: closure
            )
        )
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
