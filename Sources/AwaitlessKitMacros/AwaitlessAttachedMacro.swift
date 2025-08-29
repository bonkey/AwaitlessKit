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

// MARK: - AwaitlessAttachedMacro

/// A macro that generates a synchronous version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function in a Noasync.run call, making it callable from synchronous contexts.
public struct AwaitlessAttachedMacro: PeerMacro, MemberMacro {
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

        // Extract prefix, output type, and availability from the attribute
        var prefix = ""
        var outputType: AwaitlessOutputType = .sync
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
                
                // Check for output type parameter
                if labeledExpr.label?.text == "as",
                   let memberAccess = labeledExpr.expression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @Awaitless(as: .publisher)
                    if memberAccess.declName.baseName.text == "publisher" {
                        #if canImport(Combine)
                        outputType = .publisher
                        #else
                        let diagnostic = Diagnostic(
                            node: Syntax(labeledExpr.expression),
                            message: AwaitlessAttachedMacroDiagnostic.combineNotAvailable)
                        context.diagnose(diagnostic)
                        return []
                        #endif
                    } else if memberAccess.declName.baseName.text == "sync" {
                        outputType = .sync
                    }
                }
            }

            // Check for availability parameter (first unlabeled argument or argument without specific label)
            for argument in arguments {
                if argument.label?.text != "prefix" && argument.label?.text != "as",
                   let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @Awaitless(.deprecated) or @Awaitless(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if argument.label?.text != "prefix" && argument.label?.text != "as",
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

        // Create the new function based on output type
        let generatedDecl: DeclSyntax = createFunction(
            from: funcDecl,
            prefix: prefix,
            outputType: outputType,
            availability: availability)
        return [generatedDecl]
    }
    
    // MARK: - MemberMacro Implementation
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Handle protocol declarations
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            return []
        }
        
        // For protocols, we create sync versions of async methods as member declarations
        var memberDeclarations: [DeclSyntax] = []
        
        // Process all members to find async functions
        for member in protocolDecl.memberBlock.members {
            // If this is an async function, create its sync version as a member declaration
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                // Check if the function is async
                let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
                
                if isAsync {
                    // Create a sync version of the async function
                    let syncFunction = createSyncFunctionSignature(
                        from: functionDecl)
                    memberDeclarations.append(DeclSyntax(syncFunction))
                }
            }
        }
        
        return memberDeclarations
    }
    
    /// Create sync effect specifiers from async ones
    private static func createSyncEffectSpecifiers(from asyncSpecifiers: FunctionEffectSpecifiersSyntax) -> FunctionEffectSpecifiersSyntax? {
        // Keep throws if present, remove async
        let isThrowing = asyncSpecifiers.description.contains("throws")
        
        if isThrowing {
            return FunctionEffectSpecifiersSyntax(
                asyncSpecifier: nil,
                throwsClause: ThrowsClauseSyntax(
                    throwsSpecifier: .keyword(.throws)))
        } else {
            return nil
        }
    }
    
    /// Creates a synchronous function signature from an async function
    private static func createSyncFunctionSignature(
        from funcDecl: FunctionDeclSyntax) -> FunctionDeclSyntax
    {
        // Remove async specifier but keep throws if present
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false
        
        let newEffectSpecifiers: FunctionEffectSpecifiersSyntax? = 
            if isThrowing {
                FunctionEffectSpecifiersSyntax(
                    asyncSpecifier: nil,
                    throwsClause: ThrowsClauseSyntax(
                        throwsSpecifier: .keyword(.throws)))
            } else {
                nil
            }
        
        let newSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: newEffectSpecifiers,
            returnClause: funcDecl.signature.returnClause)
        
        return FunctionDeclSyntax(
            attributes: AttributeListSyntax([]),
            modifiers: funcDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: funcDecl.name,
            genericParameterClause: funcDecl.genericParameterClause,
            signature: newSignature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: nil)
    }

    /// Creates a function based on the specified output type
    private static func createFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        outputType: AwaitlessOutputType,
        availability: AwaitlessAvailability?)
        -> DeclSyntax
    {
        switch outputType {
        case .sync:
            return DeclSyntax(createSyncFunction(
                from: funcDecl,
                prefix: prefix,
                availability: availability))
        case .publisher:
            #if canImport(Combine)
            return DeclSyntax(createPublisherFunction(
                from: funcDecl,
                prefix: prefix,
                availability: availability))
            #else
            // This should never be reached due to earlier validation,
            // but provide a fallback just in case
            return DeclSyntax(createSyncFunction(
                from: funcDecl,
                prefix: prefix,
                availability: availability))
            #endif
        }
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
    
    /// Creates a publisher version of the provided async function
    #if canImport(Combine)
    private static func createPublisherFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,

        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract return type
        let (returnTypeSyntax, _) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false
        
        // Determine publisher return type
        let publisherReturnType: TypeSyntax = 
            if isThrowing {
                if let returnType = returnTypeSyntax {
                    TypeSyntax(IdentifierTypeSyntax(name: .identifier("AnyPublisher<\(returnType.description), Error>")))
                } else {
                    TypeSyntax(IdentifierTypeSyntax(name: .identifier("AnyPublisher<Void, Error>")))
                }
            } else {
                if let returnType = returnTypeSyntax {
                    TypeSyntax(IdentifierTypeSyntax(name: .identifier("AnyPublisher<\(returnType.description), Never>")))
                } else {
                    TypeSyntax(IdentifierTypeSyntax(name: .identifier("AnyPublisher<Void, Never>")))
                }
            }

        // Create the function body that creates a publisher
        let newBody = createPublisherFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters,
            isThrowing: isThrowing,
            returnType: returnTypeSyntax)

        // Create the new function signature
        let newSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: nil, // No async or throws for publisher functions
            returnClause: ReturnClauseSyntax(type: publisherReturnType))

        // Create attributes for the new function
        var attributes = filterAttributes(funcDecl.attributes)

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
    #endif

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
    
    /// Creates the function body that creates a publisher from an async function
    #if canImport(Combine)
    private static func createPublisherFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isThrowing: Bool,
        returnType: TypeSyntax?)
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

        // Create the Future publisher call
        let publisherCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Future")),
                period: .periodToken(),
                name: .identifier("init")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                    label: .identifier("attemptToFulfill"),
                    colon: .colonToken(),
                    expression: innerClosure)
            },
            rightParen: .rightParenToken())
        
        // Add .eraseToAnyPublisher()
        let erasedPublisher = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: ExprSyntax(publisherCall),
                period: .periodToken(),
                name: .identifier("eraseToAnyPublisher")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken())

        // Create the return statement with erased publisher
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(ExprSyntax(erasedPublisher)))
            })
    }
    #endif

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

        #if compiler(>=6.0)
            // Add 'try' if the original function throws
            if isThrowing {
                return ExprSyntax(TryExprSyntax(expression: ExprSyntax(taskNoasyncCall)))
            } else {
                return ExprSyntax(taskNoasyncCall)
            }
        #else
            // In Swift Syntax 5.10, always throw due to different Nosync.run() signature
            return ExprSyntax(TryExprSyntax(expression: ExprSyntax(taskNoasyncCall)))
        #endif
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
        #if compiler(<6.0)
            /// In Swift 5.x, always throw due to different Nosync.run() signature
            let isThrowing = true
        #endif

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
    case combineNotAvailable = "@Awaitless publisher output requires Combine framework, which is not available on this platform"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}
