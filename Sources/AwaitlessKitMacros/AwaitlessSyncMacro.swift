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

// MARK: - AwaitlessSyncMacro

/// A macro that generates a synchronous version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function in a Awaitless.run call, making it callable from synchronous contexts.
public struct AwaitlessSyncMacro: PeerMacro {
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
                message: AwaitlessSyncMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(
                node: diagnosticNode,
                message: AwaitlessSyncMacroDiagnostic.requiresAsync)
            context.diagnose(diagnostic)
            return []
        }

        // Extract prefix and availability from the attribute
        var methodPrefix: String? = nil
        var methodAvailability: AwaitlessAvailability? = nil

        if case let .argumentList(arguments) = node.arguments {
            // Check for prefix parameter
            for argument in arguments {
                let labeledExpr = argument
                if labeledExpr.label?.text == "prefix",
                   let stringLiteral = labeledExpr.expression.as(StringLiteralExprSyntax.self)
                {
                    // Extract prefix from the string literal
                    let prefixValue = stringLiteral.segments.description
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    methodPrefix = prefixValue.isEmpty ? nil : prefixValue
                }
            }

            // Check for availability parameter (first unlabeled argument or argument without specific label)
            for argument in arguments {
                if argument.label?.text != "prefix",
                   let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @Awaitless(.deprecated) or @Awaitless(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        methodAvailability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        methodAvailability = .unavailable()
                    }
                } else if argument.label?.text != "prefix",
                          let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
                          let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @Awaitless(.deprecated("message")) or @Awaitless(.unavailable("message"))
                    if calledExpr.declName.baseName.text == "deprecated" {
                        if let firstArgument = functionCall.arguments.first?.expression
                            .as(StringLiteralExprSyntax.self)
                        {
                            let message = firstArgument.segments.description
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            methodAvailability = .deprecated(message)
                        } else {
                            methodAvailability = .deprecated()
                        }
                    } else if calledExpr.declName.baseName.text == "unavailable" {
                        if let firstArgument = functionCall.arguments.first?.expression
                            .as(StringLiteralExprSyntax.self)
                        {
                            let message = firstArgument.segments.description
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            methodAvailability = .unavailable(message)
                        } else {
                            methodAvailability = .unavailable()
                        }
                    }
                }
            }
        }

        // Resolve configuration using the hierarchy
        // For now, we can't easily access the parent type, so we'll use basic resolution
        let resolvedConfig = resolveConfiguration(
            methodPrefix: methodPrefix,
            methodAvailability: methodAvailability,
            methodDelivery: nil, // @Awaitless doesn't use delivery
            methodStrategy: nil, // @Awaitless doesn't use strategy
            typeDeclaration: nil, // TODO: Get parent type declaration
            builtInPrefix: "" // @Awaitless uses empty string as default
        )

        // Create the sync function
        let generatedDecl = DeclSyntax(Self.createSyncFunction(
            from: funcDecl,
            prefix: resolvedConfig.prefix ?? "",
            availability: resolvedConfig.availability))
        return [generatedDecl]
    }

    /// Creates a synchronous version of the provided async function
    private static func createSyncFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract return type and determine if the function throws
        let (returnTypeSyntax, _) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false

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

        // Add noasync attribute to all generated functions
        let noasyncAttr = createNoasyncAttribute()
        attributes = attributes + [AttributeListSyntax.Element(noasyncAttr)]

        // Add availability attribute if needed
        if let availability {
            let availabilityAttr = createAvailabilityAttribute(
                originalFuncName: originalFuncName,
                availability: availability)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
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

    /// Creates a noasync attribute for the function
    private static func createNoasyncAttribute() -> AttributeSyntax {
        AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier("available")),
            leftParen: .leftParenToken(),
            arguments: .argumentList(
                LabeledExprListSyntax {
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(baseName: .stringSegment("*")))
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(baseName: .identifier("noasync")))
                }),
            rightParen: .rightParenToken())
    }

    /// Creates an availability attribute for the function
    private static func createAvailabilityAttribute(
        originalFuncName: String,
        availability: AwaitlessAvailability)
        -> AttributeSyntax
    {
        switch availability {
        case let .deprecated(messageOpt):
            // Create default message if none provided
            let message = messageOpt ?? "Use async \(originalFuncName) function instead"

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
                    }),
                rightParen: .rightParenToken())

        case let .unavailable(messageOpt):
            // Create default message if none provided
            let message = messageOpt ?? "This synchronous version of \(originalFuncName) is unavailable"

            // Format as: @available(*, unavailable, message: "<message>")
            return AttributeSyntax(
                attributeName: IdentifierTypeSyntax(name: .identifier("available")),
                leftParen: .leftParenToken(),
                arguments: .argumentList(
                    LabeledExprListSyntax {
                        LabeledExprSyntax(
                            expression: DeclReferenceExprSyntax(baseName: .stringSegment("*")))
                        LabeledExprSyntax(
                            expression: DeclReferenceExprSyntax(baseName: .identifier("unavailable")))
                        LabeledExprSyntax(
                            label: .identifier("message"),
                            colon: .colonToken(),
                            expression: StringLiteralExprSyntax(content: message))
                    }),
                rightParen: .rightParenToken())
        }
    }

    /// Creates the function body that wraps the async call in Awaitless.run
    private static func createSyncFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isThrowing: Bool)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original async function
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier(originalFuncName)),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken())

        // Add await to the async call
        let awaitExpression = AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr))

        // If the original function throws, add try to the call
        let innerCallExpr: ExprSyntax = isThrowing
            ? ExprSyntax(TryExprSyntax(expression: awaitExpression))
            : ExprSyntax(awaitExpression)

        // Create the closure to pass to Noasync.run with proper formatting
        let innerClosure = ClosureExprSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(innerCallExpr))
            },
            rightBrace: .rightBraceToken(leadingTrivia: .newline)
        )

        // Create the Awaitless.run call
        let taskNoasyncCall = createTaskNoasyncCall(with: ExprSyntax(innerClosure), isThrowing: isThrowing)

        // Create the function body with the Awaitless.run call
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(taskNoasyncCall))
            })
    }

    /// Creates a Noasync.run function call with trailing closure syntax
    private static func createTaskNoasyncCall(with closure: ExprSyntax, isThrowing: Bool) -> ExprSyntax {
        // Create Noasync.run with trailing closure syntax (no parentheses)
        let taskNoasyncCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Awaitless")),
                period: .periodToken(),
                name: .identifier("run")),
            leftParen: nil,
            arguments: LabeledExprListSyntax([]), // Empty arguments since we use trailing closure
            rightParen: nil,
            trailingClosure: closure.as(ClosureExprSyntax.self) // Use trailing closure
        )

        // Add 'try' if the original function throws
        if isThrowing {
            return ExprSyntax(TryExprSyntax(expression: ExprSyntax(taskNoasyncCall)))
        } else {
            return ExprSyntax(taskNoasyncCall)
        }
    }

    /// Creates a function signature for the sync version of the function
    private static func createSyncFunctionSignature(
        from funcDecl: FunctionDeclSyntax,
        isThrowing: Bool,
        returnType: TypeSyntax?)
        -> FunctionSignatureSyntax
    {
        // Create new effect specifiers for the function
        let newEffectSpecifiers: FunctionEffectSpecifiersSyntax? =
            if isThrowing {
                FunctionEffectSpecifiersSyntax(
                    asyncSpecifier: nil,
                    throwsClause: ThrowsClauseSyntax(
                        throwsSpecifier: .keyword(.throws)))
            } else {
                nil
            }

        return FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: newEffectSpecifiers,
            returnClause: returnType.map { ReturnClauseSyntax(type: $0) })
    }
}

// MARK: - AwaitlessSyncMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessSync macro
enum AwaitlessSyncMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@Awaitless can only be applied to functions"
    case requiresAsync = "@Awaitless requires the function to be 'async'"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}
