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
/// async function in a Noasync.run call, making it callable from synchronous contexts.
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
                    // Handle cases like: @Awaitless(.deprecated) or @Awaitless(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
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

        // Create the sync function
        let generatedDecl: DeclSyntax = DeclSyntax(Self.createSyncFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability))
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

    /// Creates the function body that wraps the async call in Noasync.run
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

        // Create the closure to pass to Noasync.run
        let innerClosure = ClosureExprSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(innerCallExpr))
            })

        // Create the Noasync.run call
        let taskNoasyncCall = createTaskNoasyncCall(with: ExprSyntax(innerClosure), isThrowing: isThrowing)

        // Create the function body with the Noasync.run call
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(taskNoasyncCall))
            })
    }
    
    /// Creates a Noasync.run function call with the provided closure
    private static func createTaskNoasyncCall(with closure: ExprSyntax, isThrowing: Bool) -> ExprSyntax {
        let taskNoasyncCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Noasync")),
                period: .periodToken(),
                name: .identifier("run")),
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
        let callArguments = parameters.enumerated().map { index, param in
            // Get the argument label (external name) and parameter name (internal name)
            let argumentLabel = param.firstName // External name (can be _)
            let parameterName = param.secondName ?? param.firstName // Internal name, fallback to firstName if nil

            // Check if this is an inout parameter by looking at the type description
            let isInout = param.type.description.contains("inout")

            // Create the expression - add & prefix for inout parameters
            let expression =
                if isInout {
                    ExprSyntax(InOutExprSyntax(expression: DeclReferenceExprSyntax(baseName: parameterName.trimmed)))
                } else {
                    ExprSyntax(DeclReferenceExprSyntax(baseName: parameterName.trimmed))
                }

            // Add trailing comma for all except the last parameter
            let trailingComma: TokenSyntax? = index < parameters.count - 1 ? .commaToken() : nil

            // Check if the parameter is unlabeled (argument label is _)
            if argumentLabel.tokenKind == .wildcard {
                return LabeledExprSyntax(
                    expression: expression,
                    trailingComma: trailingComma)
            } else {
                return LabeledExprSyntax(
                    label: argumentLabel.trimmed,
                    colon: .colonToken(),
                    expression: expression,
                    trailingComma: trailingComma)
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

    /// Filters out the Awaitless attribute from the attributes list
    private static func filterAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
        attributes.filter { attr in
            if case let .attribute(actualAttr) = attr,
               let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
               (attrName.name.text == "Awaitless" || attrName.name.text == "AwaitlessPublisher" || attrName.name.text == "AwaitlessCompletion")
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

// MARK: - AwaitlessSyncMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessSync macro
enum AwaitlessSyncMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@Awaitless can only be applied to functions"
    case requiresAsync = "@Awaitless requires the function to be 'async'"

    var severity: DiagnosticSeverity {
        return .error
    }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}