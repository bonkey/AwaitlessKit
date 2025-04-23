//
// Copyright (c) 2025 Daniel Bauke
//

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

// MARK: - AwaitlessAttachedMacro

/// A macro that generates a synchronous version of an async function.
/// This macro creates a twin function with prefix "awaitless_" that wraps the original
/// async function in a Task.noasync call, making it callable from synchronous contexts.
public struct AwaitlessAttachedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        // Validate that the declaration is a function
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitlessAttachedMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // Validate that the function is marked as async
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(
                node: diagnosticNode,
                message: AwaitlessAttachedMacroDiagnostic.requiresAsync)
            context.diagnose(diagnostic)
            return []
        }

        // Extract deprecated and deprecatedMessage arguments from the attribute
        var isDeprecated = false
        var deprecatedMessage: String? = nil

        if case let .argumentList(arguments) = node.arguments {
            for argument in arguments {
                if let label = argument.label?.text {
                    if label == "deprecated", let expr = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        isDeprecated = expr.literal.tokenKind == .keyword(.true)
                    } else if label == "deprecatedMessage", let expr = argument.expression.as(StringLiteralExprSyntax.self) {
                        deprecatedMessage = expr.segments.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        // Create the new synchronous function
        let syncFunction = createSyncFunction(from: funcDecl, deprecated: isDeprecated, deprecatedMessage: deprecatedMessage)
        return [DeclSyntax(syncFunction)]
    }

    /// Creates a synchronous version of the provided async function
    private static func createSyncFunction(
        from funcDecl: FunctionDeclSyntax,
        deprecated: Bool,
        deprecatedMessage: String?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = "awaitless_" + originalFuncName

        // Extract return type and determine if the function throws
        let (returnTypeSyntax, _) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsClause != nil

        // Create the function body that calls the original async function
        let newBody = createSyncFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters,
            isThrowing: isThrowing)

        // Create the new function signature (without async, but preserving throws if needed)
        let newSignature = createSyncFunctionSignature(
            from: funcDecl,
            isThrowing: isThrowing,
            returnType: returnTypeSyntax)

        // Create attributes for the new function
        var attributes = filterAttributes(funcDecl.attributes)

        // Add deprecation attribute if needed
        if deprecated {
            let deprecationAttr = createDeprecationAttribute(
                originalFuncName: originalFuncName,
                deprecatedMessage: deprecatedMessage)
            attributes = attributes + [AttributeListSyntax.Element(deprecationAttr)]
        }

        // Create the new function, copying most attributes from the original
        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: funcDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName),
            genericParameterClause: funcDecl.genericParameterClause,
            signature: newSignature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: newBody)
    }

    /// Creates a deprecation attribute for the function
    private static func createDeprecationAttribute(
        originalFuncName: String,
        deprecatedMessage: String?)
        -> AttributeSyntax
    {
        // Create default message if none provided
        let message = deprecatedMessage ?? "Use async \(originalFuncName) function instead"

        // Format as: @available(*, deprecated, message: "<message>", renamed: "<originalFunc>")
        return AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier("available")),
            leftParen: .leftParenToken(),
            arguments: .argumentList(
                LabeledExprListSyntax {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(baseName: .stringSegment("*")))
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(baseName: .identifier("deprecated")))
                    LabeledExprSyntax(
                        label: .identifier("message"),
                        colon: .colonToken(),
                        expression: StringLiteralExprSyntax(content: message))
                    LabeledExprSyntax(
                        label: .identifier("renamed"),
                        colon: .colonToken(),
                        expression: StringLiteralExprSyntax(content: originalFuncName))
                }
            ),
            rightParen: .rightParenToken())
    }

    /// Creates the function body that wraps the async call in Task.noasync
    private static func createSyncFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isThrowing: Bool)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original async function
        let asyncCallExpr = ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier(originalFuncName)),
                leftParen: .leftParenToken(),
                arguments: argumentList,
                rightParen: .rightParenToken()))

        // Add await to the async call
        let awaitExpression = ExprSyntax(AwaitExprSyntax(expression: asyncCallExpr))

        // If the original function throws, add try to the call
        let innerCallExpr = isThrowing
            ? ExprSyntax(TryExprSyntax(expression: awaitExpression))
            : awaitExpression

        // Create the closure to pass to Task.noasync
        let innerClosure = ExprSyntax(
            ClosureExprSyntax(
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(item: .expr(innerCallExpr))
                }))

        // Create the Task.noasync call
        let taskNoasyncCall = createTaskNoasyncCall(with: innerClosure, isThrowing: isThrowing)

        // Create the function body with the Task.noasync call
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(ExprSyntax(taskNoasyncCall)))
            })
    }

    /// Creates a Task.noasync function call with the provided closure
    private static func createTaskNoasyncCall(with closure: ExprSyntax, isThrowing: Bool) -> ExprSyntax {
        let taskNoasyncCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Task")),
                period: .periodToken(),
                name: .identifier("noasync")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(expression: closure)
            },
            rightParen: .rightParenToken())

        // Add 'try' if the original function throws
        if isThrowing {
            return ExprSyntax(TryExprSyntax(expression: ExprSyntax(taskNoasyncCall)))
        } else {
            return ExprSyntax(taskNoasyncCall)
        }
    }

    /// Creates argument list from function parameters
    private static func createArgumentList(from parameters: FunctionParameterListSyntax) -> LabeledExprListSyntax {
        let callArguments = parameters.map { param in
            let internalName = param.firstName
            let externalName = param.secondName ?? internalName

            if externalName.tokenKind == .wildcard {
                return LabeledExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: internalName.trimmed))
            } else {
                return LabeledExprSyntax(
                    label: externalName.trimmed,
                    expression: DeclReferenceExprSyntax(baseName: internalName.trimmed))
            }
        }
        return LabeledExprListSyntax(callArguments)
    }

    /// Creates a function signature for the sync version of the function
    private static func createSyncFunctionSignature(
        from funcDecl: FunctionDeclSyntax,
        isThrowing: Bool,
        returnType: TypeSyntax?)
        -> FunctionSignatureSyntax
    {
        // Preserve the throws specifier if needed
        let throwsSpecifier = isThrowing ? funcDecl.signature.effectSpecifiers?.throwsClause?.trimmed : nil
        let newEffectSpecifiers = FunctionEffectSpecifiersSyntax(
            throwsClause: throwsSpecifier).trimmed

        return FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: newEffectSpecifiers.throwsClause != nil ? newEffectSpecifiers : nil,
            returnClause: returnType.map { ReturnClauseSyntax(type: $0) })
    }

    /// Filters out the Awaitless attribute from the attributes list
    private static func filterAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
        attributes.filter { attr in
            if case let .attribute(actualAttr) = attr,
               let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
               attrName.name.text == "Awaitless"
            {
                return false
            }
            return true
        }
    }

    /// Extracts the return type from a function declaration
    /// Returns a tuple with:
    /// - The return type syntax (or nil if the function returns Void implicitly)
    /// - A boolean indicating if the return type is Void
    private static func extractReturnType(funcDecl: FunctionDeclSyntax) -> (TypeSyntax?, Bool) {
        if let returnClause = funcDecl.signature.returnClause {
            let returnType = returnClause.type.trimmed

            // Check if return type is explicitly Void
            if let simpleType = returnType.as(IdentifierTypeSyntax.self), simpleType.name.text == "Void" {
                return (returnType, true)
            }

            // Check if return type is an empty tuple () which is equivalent to Void
            if let tupleType = returnType.as(TupleTypeSyntax.self), tupleType.elements.isEmpty {
                return (returnType, true)
            }

            // Not a Void return type
            return (returnType, false)
        } else {
            // Implicit Void return type (no return clause)
            return (nil, true)
        }
    }
}

// MARK: - AwaitlessAttachedMacroDiagnostic

/// Diagnostics for errors related to the Awaitless macro
enum AwaitlessAttachedMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@Awaitless can only be applied to functions"
    case requiresAsync = "@Awaitless requires the function to be 'async'"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}
