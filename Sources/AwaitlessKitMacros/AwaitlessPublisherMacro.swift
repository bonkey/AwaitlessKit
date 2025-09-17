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
        if declaration.is(ProtocolDeclSyntax.self) {
            return []
        }
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitlessPublisherMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        var prefix = ""
        var availability: AwaitlessAvailability? = nil
        var delivery: AwaitlessDelivery = .current

        if case let .argumentList(arguments) = node.arguments {
            for argument in arguments {
                let labeledExpr = argument
                if labeledExpr.label?.text == "prefix",
                   let stringLiteral = labeledExpr.expression.as(StringLiteralExprSyntax.self)
                {
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

            for argument in arguments {
                if argument.label?.text != "prefix", argument.label?.text != "deliverOn",
                   let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
                {
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if argument.label?.text != "prefix", argument.label?.text != "deliverOn",
                          let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
                          let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
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

        #if canImport(Combine)
            let generatedDecl = DeclSyntax(Self.createPublisherFunction(
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

    // Creates a publisher version of the provided async function
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
            let publisherReturnType =
                if isThrowing {
                    if let returnType = returnTypeSyntax {
                        TypeSyntax(
                            IdentifierTypeSyntax(name: .identifier("AnyPublisher<\(returnType.description), Error>")))
                    } else {
                        TypeSyntax(IdentifierTypeSyntax(name: .identifier("AnyPublisher<Void, Error>")))
                    }
                } else {
                    if let returnType = returnTypeSyntax {
                        TypeSyntax(
                            IdentifierTypeSyntax(name: .identifier("AnyPublisher<\(returnType.description), Never>")))
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

        /// Creates the function body that creates a publisher from an async function
        private static func createPublisherFunctionBody(
            originalFuncName: String,
            parameters: FunctionParameterListSyntax,
            isThrowing: Bool,
            returnType: TypeSyntax?,
            delivery: AwaitlessDelivery)
            -> CodeBlockSyntax
        {
            let argumentList = createArgumentList(from: parameters)

            // self.originalFuncName(<args>)
            let baseCall = FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                    period: .periodToken(),
                    name: .identifier(originalFuncName)),
                leftParen: .leftParenToken(),
                arguments: argumentList,
                rightParen: .rightParenToken())

            // await (+ try) self.originalFuncName(...)
            let awaited: ExprSyntax = {
                let awaitedExpr = AwaitExprSyntax(expression: ExprSyntax(baseCall))
                if isThrowing {
                    return ExprSyntax(TryExprSyntax(expression: awaitedExpr))
                } else {
                    return ExprSyntax(awaitedExpr)
                }
            }()

            // AwaitlessCombineFactory.makeThrowing { ... }  OR  makeNonThrowing { ... }
            let factoryName = isThrowing ? "makeThrowing" : "makeNonThrowing"

            let factoryCall = FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessCombineFactory")),
                    period: .periodToken(),
                    name: .identifier(factoryName)),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax(),
                rightParen: .rightParenToken(),
                trailingClosure: ClosureExprSyntax(
                    statements: CodeBlockItemListSyntax {
                        CodeBlockItemSyntax(item: .expr(awaited))
                    }))

            // Optional delivery adaptation
            let deliveredExpr: ExprSyntax = {
                switch delivery {
                case .main:
                    // Add receive(on:) then erase to AnyPublisher so the return type matches
                    return ExprSyntax(
                        FunctionCallExprSyntax(
                            calledExpression: MemberAccessExprSyntax(
                                base: FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                        base: ExprSyntax(factoryCall),
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
                                                    name: .identifier("main"))))
                                    },
                                    rightParen: .rightParenToken()),
                                period: .periodToken(),
                                name: .identifier("eraseToAnyPublisher")),
                            leftParen: .leftParenToken(),
                            arguments: LabeledExprListSyntax(),
                            rightParen: .rightParenToken()))
                case .current:
                    return ExprSyntax(factoryCall)
                }
            }()

            return CodeBlockSyntax(
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(item: .expr(deliveredExpr))
                })
        }

    #endif
}

// MARK: - AwaitlessPublisherMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessPublisher macro
enum AwaitlessPublisherMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitlessPublisher can only be applied to functions"
    case combineNotAvailable = "@AwaitlessPublisher requires Combine framework, which is not available on this platform"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}
