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

// MARK: - CompletionBlockAttachedMacro

/// A macro that generates a completion block version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function in a Task and calls a completion handler with Result<T, Error>.
public struct CompletionBlockAttachedMacro: PeerMacro {
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
                message: CompletionBlockAttachedMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // Validate that the function is marked as async
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(
                node: diagnosticNode,
                message: CompletionBlockAttachedMacroDiagnostic.requiresAsync)
            context.diagnose(diagnostic)
            return []
        }

        // Extract prefix and availability from the attribute
        var prefix = "withCompletion"
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

            // Check for availability parameter (first unlabeled argument)
            if let firstArg = arguments.first,
               !(firstArg.label?.text == "prefix")
            {
                if let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self) {
                    // Handle cases like: @CompletionBlock(.deprecated) or @CompletionBlock(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if let functionCall = firstArg.expression.as(FunctionCallExprSyntax.self),
                          let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @CompletionBlock(.deprecated("message")) or @CompletionBlock(.unavailable("message"))
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

        // Create the new completion block function
        let completionFunction = createCompletionFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability)
        return [DeclSyntax(completionFunction)]
    }

    /// Creates a completion block version of the provided async function
    private static func createCompletionFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = originalFuncName + prefix.capitalized

        // Extract return type and determine if the function throws
        let (returnTypeSyntax, isVoid) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false

        // Create the function body that calls the original async function
        let newBody = createCompletionFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters,
            returnType: returnTypeSyntax,
            isVoid: isVoid,
            isThrowing: isThrowing)

        // Create the new function signature with completion parameter
        let newSignature = createCompletionFunctionSignature(
            from: funcDecl,
            returnType: returnTypeSyntax,
            isVoid: isVoid)

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
            let message = messageOpt ?? "This completion block version of \(originalFuncName) is unavailable"

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

    /// Creates the function body that wraps the async call in a Task and calls completion
    private static func createCompletionFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        returnType: TypeSyntax?,
        isVoid: Bool,
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

        // Create the Task body with proper error handling
        let taskBody = createTaskBody(
            awaitExpression: awaitExpression,
            isVoid: isVoid,
            isThrowing: isThrowing)

        // Create the Task call
        let taskCall = ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Task")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(expression: taskBody)
                },
                rightParen: .rightParenToken()))

        // Create the function body with the Task call
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(taskCall))
            })
    }

    /// Creates the Task body with proper error handling and completion calls
    private static func createTaskBody(
        awaitExpression: ExprSyntax,
        isVoid: Bool,
        isThrowing: Bool)
        -> ExprSyntax
    {
        if isThrowing {
            // For throwing functions, use do-catch with Result
            let doBlock = CodeBlockSyntax(
                statements: CodeBlockItemListSyntax {
                    if isVoid {
                        // For void functions: try await call, then completion(.success(()))
                        CodeBlockItemSyntax(
                            item: .expr(ExprSyntax(TryExprSyntax(expression: awaitExpression))))
                        CodeBlockItemSyntax(
                            item: .expr(createCompletionCall(isSuccess: true, isVoid: true)))
                    } else {
                        // For non-void functions: let result = try await call, then completion(.success(result))
                        CodeBlockItemSyntax(
                            item: .stmt(StmtSyntax(
                                VariableDeclSyntax(
                                    bindingSpecifier: .keyword(.let),
                                    bindings: PatternBindingListSyntax {
                                        PatternBindingSyntax(
                                            pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                            initializer: InitializerClauseSyntax(
                                                value: ExprSyntax(TryExprSyntax(expression: awaitExpression))))
                                    }))))
                        CodeBlockItemSyntax(
                            item: .expr(createCompletionCall(isSuccess: true, isVoid: false)))
                    }
                })

            let catchBlock = CodeBlockSyntax(
                statements: CodeBlockItemListSyntax {
                    CodeBlockItemSyntax(
                        item: .expr(createCompletionCall(isSuccess: false, isVoid: isVoid)))
                })

            return ExprSyntax(
                ClosureExprSyntax(
                    statements: CodeBlockItemListSyntax {
                        CodeBlockItemSyntax(
                            item: .stmt(StmtSyntax(
                                DoStmtSyntax(
                                    body: doBlock,
                                    catchClauses: CatchClauseListSyntax {
                                        CatchClauseSyntax(
                                            catchKeyword: .keyword(.catch),
                                            body: catchBlock)
                                    }))))
                    }))
        } else {
            // For non-throwing functions, just call completion with success
            return ExprSyntax(
                ClosureExprSyntax(
                    statements: CodeBlockItemListSyntax {
                        if isVoid {
                            CodeBlockItemSyntax(item: .expr(awaitExpression))
                            CodeBlockItemSyntax(
                                item: .expr(createCompletionCall(isSuccess: true, isVoid: true)))
                        } else {
                            CodeBlockItemSyntax(
                                item: .stmt(StmtSyntax(
                                    VariableDeclSyntax(
                                        bindingSpecifier: .keyword(.let),
                                        bindings: PatternBindingListSyntax {
                                            PatternBindingSyntax(
                                                pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                                initializer: InitializerClauseSyntax(value: awaitExpression))
                                        }))))
                            CodeBlockItemSyntax(
                                item: .expr(createCompletionCall(isSuccess: true, isVoid: false)))
                        }
                    }))
        }
    }

    /// Creates a completion call expression
    private static func createCompletionCall(isSuccess: Bool, isVoid: Bool) -> ExprSyntax {
        if isSuccess {
            if isVoid {
                // completion(.success(()))
                return ExprSyntax(
                    FunctionCallExprSyntax(
                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("completion")),
                        leftParen: .leftParenToken(),
                        arguments: LabeledExprListSyntax {
                            LabeledExprSyntax(
                                expression: ExprSyntax(
                                    FunctionCallExprSyntax(
                                        calledExpression: MemberAccessExprSyntax(
                                            base: DeclReferenceExprSyntax(baseName: .identifier("Result")),
                                            period: .periodToken(),
                                            name: .identifier("success")),
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax {
                                            LabeledExprSyntax(
                                                expression: ExprSyntax(
                                                    TupleExprSyntax(elements: LabeledExprListSyntax())))
                                        },
                                        rightParen: .rightParenToken())))
                        },
                        rightParen: .rightParenToken()))
            } else {
                // completion(.success(result))
                return ExprSyntax(
                    FunctionCallExprSyntax(
                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("completion")),
                        leftParen: .leftParenToken(),
                        arguments: LabeledExprListSyntax {
                            LabeledExprSyntax(
                                expression: ExprSyntax(
                                    FunctionCallExprSyntax(
                                        calledExpression: MemberAccessExprSyntax(
                                            base: DeclReferenceExprSyntax(baseName: .identifier("Result")),
                                            period: .periodToken(),
                                            name: .identifier("success")),
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax {
                                            LabeledExprSyntax(
                                                expression: DeclReferenceExprSyntax(baseName: .identifier("result")))
                                        },
                                        rightParen: .rightParenToken())))
                        },
                        rightParen: .rightParenToken()))
            }
        } else {
            // completion(.failure(error))
            return ExprSyntax(
                FunctionCallExprSyntax(
                    calledExpression: DeclReferenceExprSyntax(baseName: .identifier("completion")),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(
                            expression: ExprSyntax(
                                FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                        base: DeclReferenceExprSyntax(baseName: .identifier("Result")),
                                        period: .periodToken(),
                                        name: .identifier("failure")),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax {
                                        LabeledExprSyntax(
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("error")))
                                    },
                                    rightParen: .rightParenToken())))
                    },
                    rightParen: .rightParenToken()))
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

    /// Creates a function signature for the completion version of the function
    private static func createCompletionFunctionSignature(
        from funcDecl: FunctionDeclSyntax,
        returnType: TypeSyntax?,
        isVoid: Bool)
        -> FunctionSignatureSyntax
    {
        // Create the completion parameter type
        let completionType = createCompletionParameterType(returnType: returnType, isVoid: isVoid)

        // Add completion parameter to the existing parameters
        var newParameters = Array(funcDecl.signature.parameterClause.parameters)
        let completionParam = FunctionParameterSyntax(
            firstName: .identifier("completion"),
            colon: .colonToken(),
            type: completionType)

        if !newParameters.isEmpty {
            // Add trailing comma to the last existing parameter
            if let lastParam = newParameters.last {
                newParameters[newParameters.count - 1] = lastParam.with(\.trailingComma, .commaToken())
            }
        }
        newParameters.append(completionParam)

        let newParameterClause = FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax(newParameters))

        return FunctionSignatureSyntax(
            parameterClause: newParameterClause,
            effectSpecifiers: nil, // Remove async and throws
            returnClause: nil) // No return value, uses completion instead
    }

    /// Creates the completion parameter type
    private static func createCompletionParameterType(returnType: TypeSyntax?, isVoid: Bool) -> TypeSyntax {
        let resultType: TypeSyntax
        if isVoid {
            // Result<Void, Error>
            resultType = TypeSyntax(
                IdentifierTypeSyntax(
                    name: .identifier("Result"),
                    genericArgumentClause: GenericArgumentClauseSyntax(
                        arguments: GenericArgumentListSyntax {
                            GenericArgumentSyntax(argument: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void"))))
                            GenericArgumentSyntax(argument: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Error"))))
                        })))
        } else if let returnType {
            // Result<ReturnType, Error>
            resultType = TypeSyntax(
                IdentifierTypeSyntax(
                    name: .identifier("Result"),
                    genericArgumentClause: GenericArgumentClauseSyntax(
                        arguments: GenericArgumentListSyntax {
                            GenericArgumentSyntax(argument: returnType)
                            GenericArgumentSyntax(argument: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Error"))))
                        })))
        } else {
            // Fallback to Result<Void, Error>
            resultType = TypeSyntax(
                IdentifierTypeSyntax(
                    name: .identifier("Result"),
                    genericArgumentClause: GenericArgumentClauseSyntax(
                        arguments: GenericArgumentListSyntax {
                            GenericArgumentSyntax(argument: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void"))))
                            GenericArgumentSyntax(argument: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Error"))))
                        })))
        }

        // @escaping (Result<T, Error>) -> Void
        return TypeSyntax(
            AttributedTypeSyntax(
                attributes: AttributeListSyntax {
                    AttributeListSyntax.Element(
                        AttributeSyntax(
                            attributeName: IdentifierTypeSyntax(name: .identifier("escaping"))))
                },
                baseType: TypeSyntax(
                    FunctionTypeSyntax(
                        parameters: TupleTypeElementListSyntax {
                            TupleTypeElementSyntax(type: resultType)
                        },
                        returnClause: ReturnClauseSyntax(
                            type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void"))))))))
    }

    /// Filters out the CompletionBlock attribute from the attributes list
    private static func filterAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
        attributes.filter { attr in
            if case let .attribute(actualAttr) = attr,
               let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
               attrName.name.text == "CompletionBlock"
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

// MARK: - CompletionBlockAttachedMacroDiagnostic

/// Diagnostics for errors related to the CompletionBlock macro
enum CompletionBlockAttachedMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@CompletionBlock can only be applied to functions"
    case requiresAsync = "@CompletionBlock requires the function to be 'async'"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "CompletionBlockMacros", id: rawValue)
    }
}

