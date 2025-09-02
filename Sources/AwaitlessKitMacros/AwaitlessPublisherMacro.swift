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
        let generatedDecl: DeclSyntax = DeclSyntax(Self.createPublisherFunction(
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
    
    /// Creates a publisher version of the provided async function
    #if canImport(Combine)
    private static func createPublisherFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?,
        delivery: AwaitlessDelivery)
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
            returnType: returnTypeSyntax,
            delivery: delivery)

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
    
    /// Creates the function body that creates a publisher from an async function
    private static func createPublisherFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isThrowing: Bool,
        returnType: TypeSyntax?,
        delivery: AwaitlessDelivery)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original async function with self.
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)
            ),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken())

        // Add await to the async call
        let awaitExpression = AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr))

        // If the original function throws, add try to the call
        let innerCallExpr: ExprSyntax = isThrowing
            ? ExprSyntax(TryExprSyntax(expression: awaitExpression))
            : ExprSyntax(awaitExpression)

        // Build the Task body statements
        let taskStatements = if isThrowing {
            CodeBlockItemListSyntax {
                // do {
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(
                    DoStmtSyntax(
                        body: CodeBlockSyntax(
                            statements: CodeBlockItemListSyntax {
                                // let result = try await originalFunc()
                                CodeBlockItemSyntax(item: .decl(DeclSyntax(
                                    VariableDeclSyntax(
                                        bindingSpecifier: .keyword(.let),
                                        bindings: PatternBindingListSyntax {
                                            PatternBindingSyntax(
                                                pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                                initializer: InitializerClauseSyntax(value: innerCallExpr)
                                            )
                                        }
                                    )
                                )))
                                // promise(.success(result))
                                CodeBlockItemSyntax(item: .expr(ExprSyntax(
                                    FunctionCallExprSyntax(
                                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("promise")),
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax {
                                            LabeledExprSyntax(
                                                expression: FunctionCallExprSyntax(
                                                    calledExpression: MemberAccessExprSyntax(
                                                        period: .periodToken(),
                                                        name: .identifier("success")
                                                    ),
                                                    leftParen: .leftParenToken(),
                                                    arguments: LabeledExprListSyntax {
                                                        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("result")))
                                                    },
                                                    rightParen: .rightParenToken()
                                                )
                                            )
                                        },
                                        rightParen: .rightParenToken()
                                    )
                                )))
                            }
                        ),
                        catchClauses: CatchClauseListSyntax {
                            CatchClauseSyntax(
                                body: CodeBlockSyntax(
                                    statements: CodeBlockItemListSyntax {
                                        // promise(.failure(error))
                                        CodeBlockItemSyntax(item: .expr(ExprSyntax(
                                            FunctionCallExprSyntax(
                                                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("promise")),
                                                leftParen: .leftParenToken(),
                                                arguments: LabeledExprListSyntax {
                                                    LabeledExprSyntax(
                                                        expression: FunctionCallExprSyntax(
                                                            calledExpression: MemberAccessExprSyntax(
                                                                period: .periodToken(),
                                                                name: .identifier("failure")
                                                            ),
                                                            leftParen: .leftParenToken(),
                                                            arguments: LabeledExprListSyntax {
                                                                LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("error")))
                                                            },
                                                            rightParen: .rightParenToken()
                                                        )
                                                    )
                                                },
                                                rightParen: .rightParenToken()
                                            )
                                        )))
                                    }
                                )
                            )
                        }
                    )
                )))
            }
        } else {
            CodeBlockItemListSyntax {
                // let result = await originalFunc()
                CodeBlockItemSyntax(item: .decl(DeclSyntax(
                    VariableDeclSyntax(
                        bindingSpecifier: .keyword(.let),
                        bindings: PatternBindingListSyntax {
                            PatternBindingSyntax(
                                pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                initializer: InitializerClauseSyntax(value: innerCallExpr)
                            )
                        }
                    )
                )))
                // promise(.success(result))
                CodeBlockItemSyntax(item: .expr(ExprSyntax(
                    FunctionCallExprSyntax(
                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("promise")),
                        leftParen: .leftParenToken(),
                        arguments: LabeledExprListSyntax {
                            LabeledExprSyntax(
                                expression: FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                        period: .periodToken(),
                                        name: .identifier("success")
                                    ),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax {
                                        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("result")))
                                    },
                                    rightParen: .rightParenToken()
                                )
                            )
                        },
                        rightParen: .rightParenToken()
                    )
                )))
            }
        }

        // Create the Task call
        let taskCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Task")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken(),
            trailingClosure: ClosureExprSyntax(
                statements: taskStatements
            )
        )

        // Create the Future closure that takes a promise parameter
        let futureClosure = ClosureExprSyntax(
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax {
                        ClosureShorthandParameterSyntax(name: .identifier("promise"))
                    }
                )
            ),
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(ExprSyntax(taskCall)))
            }
        )

        // Create the Future publisher call
        let publisherCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Future")),
                period: .periodToken(),
                name: .identifier("init")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
                LabeledExprSyntax(
                    expression: ExprSyntax(futureClosure))
            },
            rightParen: .rightParenToken())
        
        // Optionally add .receive(on: DispatchQueue.main)
        let baseForErase: ExprSyntax = {
            switch delivery {
            case .main:
                let receiveCall = FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: ExprSyntax(publisherCall),
                        period: .periodToken(),
                        name: .identifier("receive")),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(
                            label: .identifier("on"),
                            colon: .colonToken(),
                            expression: ExprSyntax(
                                MemberAccessExprSyntax(
                                    base: DeclReferenceExprSyntax(baseName: .identifier("DispatchQueue")),
                                    period: .periodToken(),
                                    name: .identifier("main")))
                        )
                    },
                    rightParen: .rightParenToken())
                return ExprSyntax(receiveCall)
            case .current:
                return ExprSyntax(publisherCall)
            }
        }()

        // Add .eraseToAnyPublisher()
        let erasedPublisher = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: baseForErase,
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
    #endif
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