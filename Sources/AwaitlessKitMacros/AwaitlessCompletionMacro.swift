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

// MARK: - AwaitlessCompletionMacro

/// A macro that generates a completion-handler version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function and calls a completion handler with the result.
public struct AwaitlessCompletionMacro: PeerMacro {
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
                message: AwaitlessCompletionMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(
                node: diagnosticNode,
                message: AwaitlessCompletionMacroDiagnostic.requiresAsync)
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
                    // Handle cases like: @AwaitlessCompletion(.deprecated) or @AwaitlessCompletion(.unavailable)
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if argument.label?.text != "prefix",
                          let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
                          let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
                {
                    // Handle cases like: @AwaitlessCompletion(.deprecated("message")) or @AwaitlessCompletion(.unavailable("message"))
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

        // Create the completion function
        let generatedDecl: DeclSyntax = DeclSyntax(Self.createCompletionFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability))
        return [generatedDecl]
    }
    
    /// Creates a completion-handler version of the provided async function
    private static func createCompletionFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract return type and determine if the function throws
        let (returnTypeSyntax, isVoidReturn) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false

        // Build the completion parameter type: Result<Return, Error>
        let resultInnerType: TypeSyntax = returnTypeSyntax ?? TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
        let completionType = TypeSyntax("@escaping (Result<\(raw: resultInnerType.description), Error>) -> Void")

        // Build parameter list: original parameters + trailing completion
        var newParams = funcDecl.signature.parameterClause.parameters
        let needsComma = !newParams.isEmpty
        let completionParam = FunctionParameterSyntax(
            firstName: .identifier("completion"),
            colon: .colonToken(),
            type: completionType,
            trailingComma: nil
        )
        if needsComma {
            // Ensure the previous parameter has a trailing comma
            if let last = newParams.last {
                newParams = FunctionParameterListSyntax(newParams.dropLast() + [
                    FunctionParameterSyntax(
                        attributes: last.attributes,
                        firstName: last.firstName,
                        secondName: last.secondName,
                        colon: last.colon,
                        type: last.type,
                        ellipsis: last.ellipsis,
                        defaultValue: last.defaultValue,
                        trailingComma: .commaToken()
                    )
                ])
            }
        }
        newParams = newParams + [completionParam]

        let newParameterClause = FunctionParameterClauseSyntax(parameters: newParams)

        // Create the function body that calls the original async function and completes
        let newBody = createCompletionFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters,
            isThrowing: isThrowing,
            isVoidReturn: isVoidReturn)

        // Signature: no async/throws and no return type
        let newSignature = FunctionSignatureSyntax(
            parameterClause: newParameterClause,
            effectSpecifiers: nil,
            returnClause: nil
        )

        // Create attributes for the new function (filter out macro attribute; do NOT add noasync)
        var attributes = filterAttributes(funcDecl.attributes)
        if let availability {
            let availabilityAttr = createAvailabilityAttribute(
                originalFuncName: originalFuncName,
                availability: availability)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
        }

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
    


    /// Creates the function body that calls the async function and finishes via completion(Result)
    private static func createCompletionFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isThrowing: Bool,
        isVoidReturn: Bool)
        -> CodeBlockSyntax
    {
        let argumentList = createArgumentList(from: parameters)

        // self.original(args...)
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)
            ),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken()
        )

        let awaitExpr = AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr))
        let innerExpr: ExprSyntax = isThrowing
            ? ExprSyntax(TryExprSyntax(expression: awaitExpr))
            : ExprSyntax(awaitExpr)

        let bodyStatements: CodeBlockItemListSyntax = if isThrowing {
            CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(
                    DoStmtSyntax(
                        body: CodeBlockSyntax(
                            statements: CodeBlockItemListSyntax {
                                // let result = try await ... (only when not void)
                                if !isVoidReturn {
                                    CodeBlockItemSyntax(item: .decl(DeclSyntax(
                                        VariableDeclSyntax(
                                            bindingSpecifier: .keyword(.let),
                                            bindings: PatternBindingListSyntax {
                                                PatternBindingSyntax(
                                                    pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                                    initializer: InitializerClauseSyntax(value: innerExpr)
                                                )
                                            }
                                        )
                                    )))
                                } else {
                                    CodeBlockItemSyntax(item: .expr(innerExpr))
                                }
                                // completion(.success(result|()))
                                CodeBlockItemSyntax(item: .expr(ExprSyntax(
                                    FunctionCallExprSyntax(
                                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("completion")),
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
                                                        if isVoidReturn {
                                                            LabeledExprSyntax(expression: TupleExprSyntax(elements: LabeledExprListSyntax()))
                                                        } else {
                                                            LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("result")))
                                                        }
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
                                        // completion(.failure(error))
                                        CodeBlockItemSyntax(item: .expr(ExprSyntax(
                                            FunctionCallExprSyntax(
                                                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("completion")),
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
                if !isVoidReturn {
                    CodeBlockItemSyntax(item: .decl(DeclSyntax(
                        VariableDeclSyntax(
                            bindingSpecifier: .keyword(.let),
                            bindings: PatternBindingListSyntax {
                                PatternBindingSyntax(
                                    pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                    initializer: InitializerClauseSyntax(value: innerExpr)
                                )
                            }
                        )
                    )))
                } else {
                    CodeBlockItemSyntax(item: .expr(innerExpr))
                }
                CodeBlockItemSyntax(item: .expr(ExprSyntax(
                    FunctionCallExprSyntax(
                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("completion")),
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
                                        if isVoidReturn {
                                            LabeledExprSyntax(expression: TupleExprSyntax(elements: LabeledExprListSyntax()))
                                        } else {
                                            LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("result")))
                                        }
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

        // Task() { ... }
        let taskCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Task")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken(),
            trailingClosure: ClosureExprSyntax(statements: bodyStatements)
        )

        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(ExprSyntax(taskCall)))
            }
        )
    }






}

// MARK: - AwaitlessCompletionMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessCompletion macro
enum AwaitlessCompletionMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitlessCompletion can only be applied to functions"
    case requiresAsync = "@AwaitlessCompletion requires the function to be 'async'"

    var severity: DiagnosticSeverity {
        return .error
    }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}