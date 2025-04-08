//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - NoasyncMacro

public struct NoasyncMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        // 1. Validate Input: Ensure it's attached to a function.
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(node: Syntax(declaration), message: NoAsyncMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // 2. Validate Input: Ensure the function is async.
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            // Point the diagnostic at the 'func' keyword or the function name if async isn't present
            // Use the function name token if available, otherwise the func keyword.
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(node: diagnosticNode, message: NoAsyncMacroDiagnostic.requiresAsync)
            context.diagnose(diagnostic)
            return []
        }

        // 3. Prepare for new function generation
        let originalFuncName = funcDecl.name.text
        let newFuncName = "noasync_" + originalFuncName

        // Extract return type for the new signature, but we don't use returnsVoid for the body anymore
        let (returnTypeSyntax, _) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil

        // 4. Construct the inner call arguments
        let callArguments = funcDecl.signature.parameterClause.parameters.map { param in
            // Use the internal name (first name) if available, otherwise the external name
            let internalName = param.firstName
            let externalName = param.secondName ?? internalName

            // If the external name is '_', it means no label in the call
            if externalName.tokenKind == .wildcard {
                return LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: internalName.trimmed))
            } else {
                // Otherwise, use the external name as the label and the internal name as the value reference
                return LabeledExprSyntax(
                    label: externalName.trimmed,
                    expression: DeclReferenceExprSyntax(baseName: internalName.trimmed))
            }
        }
        let argumentList = LabeledExprListSyntax(callArguments)

        // 5. Build the expression for the call to the original async function
        let asyncCallExpr = ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier(originalFuncName)),
                leftParen: .leftParenToken(),
                arguments: argumentList,
                rightParen: .rightParenToken()))

        // Add await, and try if the original function was throwing
        let awaitExpression = ExprSyntax(AwaitExprSyntax(expression: asyncCallExpr))
        let innerCallExpr =
            if isThrowing {
                ExprSyntax(TryExprSyntax(expression: awaitExpression))
            } else {
                awaitExpression
            }

        // Build the inner closure: { await originalFunc(...) } or { try await originalFunc(...) }
        let innerClosure = ExprSyntax(
            ClosureExprSyntax(
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(item: .expr(innerCallExpr))
                }))

        // Build the Task.noasync call: Task.noasync({ ... })
        let taskNoasyncCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Task")),
                period: .periodToken(),
                name: .identifier("noasync")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(expression: innerClosure) // Pass the closure as argument
            },
            rightParen: .rightParenToken())

        // Create the body containing only the Task.noasync call
        let newBody = CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                // The body is just the expression: Task.noasync({ await originalFunc(...) })
                CodeBlockItemSyntax(item: .expr(ExprSyntax(taskNoasyncCall)))
            })

        // 6. Build the new function signature (remove async, keep throws)
        // Preserve original throws specifier trivia if possible
        let throwsSpecifier = isThrowing ? funcDecl.signature.effectSpecifiers?.throwsSpecifier?.trimmed : nil
        let newEffectSpecifiers = FunctionEffectSpecifiersSyntax(
            throwsSpecifier: throwsSpecifier).trimmed

        let newSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause, // Keep original parameters
            effectSpecifiers: newEffectSpecifiers.throwsSpecifier != nil ? newEffectSpecifiers : nil,
            // Omit if not throwing
            returnClause: returnTypeSyntax.map { ReturnClauseSyntax(type: $0) } // Keep original return type
        )

        // 7. Assemble the new function declaration
        let newFunc = FunctionDeclSyntax(
            attributes: funcDecl.attributes.filter { attr in // Filter out the @noasync attribute itself
                if case let .attribute(actualAttr) = attr,
                   let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
                   attrName.name.text == "Noasync"
                {
                    return false
                }
                return true
            },
            modifiers: funcDecl.modifiers, // Keep original modifiers (public, etc.)
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName),
            genericParameterClause: funcDecl.genericParameterClause, // Keep generics
            signature: newSignature,
            genericWhereClause: funcDecl.genericWhereClause, // Keep where clauses
            body: newBody)

        return [DeclSyntax(newFunc)]
    }

    /// Helper to get return type (handles implicit Void)
    /// Returns the TypeSyntax? for the signature, and a Bool indicating if it's Void
    private static func extractReturnType(funcDecl: FunctionDeclSyntax) -> (TypeSyntax?, Bool) {
        if let returnClause = funcDecl.signature.returnClause {
            let returnType = returnClause.type.trimmed
            // Check for explicit Void or ()
            if let simpleType = returnType.as(IdentifierTypeSyntax.self), simpleType.name.text == "Void" {
                return (returnType, true) // Explicit Void
            }
            if let tupleType = returnType.as(TupleTypeSyntax.self), tupleType.elements.isEmpty {
                return (returnType, true) // Empty tuple () which is Void
            }
            return (returnType, false) // Some other type
        } else {
            // No explicit return type means it returns Void implicitly
            // For the signature, we represent this as `nil` returnClause
            return (nil, true)
        }
    }
}

// MARK: - NoAsyncMacroDiagnostic

/// Diagnostics messages
enum NoAsyncMacroDiagnostic: String,
    DiagnosticMessage
{ // Removed Error conformance as it's not strictly needed for DiagnosticMessage
    case requiresFunction = "@Noasync can only be applied to functions" // Updated macro name
    case requiresAsync = "@Noasync requires the function to be 'async'" // Updated macro name

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "NoAsyncMacros", id: rawValue)
    }
}

// MARK: - NoAsyncPlugin

/// Plugin Entry Point
@main
struct NoAsyncPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NoasyncMacro.self,
    ]
}

@attached(peer, names: arbitrary)
public macro Noasync() = #externalMacro(module: "NoasyncMacro", type: "NoasyncMacro")
