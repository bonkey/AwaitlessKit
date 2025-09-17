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
import PromiseKit

// MARK: - AwaitlessPromiseMacro

/// A macro that generates a PromiseKit Promise version of an async function.
/// This macro creates a twin function with specified prefix that wraps the original
/// async function in a Promise, making it consumable via PromiseKit.
public struct AwaitlessPromiseMacro: PeerMacro {
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
                message: AwaitlessPromiseMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let diagnosticNode = Syntax(funcDecl.name)
            let diagnostic = Diagnostic(
                node: diagnosticNode,
                message: AwaitlessPromiseMacroDiagnostic.requiresAsync)
            context.diagnose(diagnostic)
            return []
        }

        var prefix = ""
        var availability: AwaitlessAvailability? = nil

        if case let .argumentList(arguments) = node.arguments {
            for argument in arguments {
                let labeledExpr = argument
                if labeledExpr.label?.text == "prefix",
                   let stringLiteral = labeledExpr.expression.as(StringLiteralExprSyntax.self)
                {
                    prefix = stringLiteral.segments.description
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }

            for argument in arguments {
                if argument.label?.text != "prefix",
                   let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
                {
                    if memberAccess.declName.baseName.text == "deprecated" {
                        availability = .deprecated()
                    } else if memberAccess.declName.baseName.text == "unavailable" {
                        availability = .unavailable()
                    }
                } else if argument.label?.text != "prefix",
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

        let generatedDecl = DeclSyntax(Self.createPromiseFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability))
        return [generatedDecl]
    }

    /// Creates a Promise version of the provided async function
    private static func createPromiseFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract return type
        let (returnTypeSyntax, isVoidReturn) = extractReturnType(funcDecl: funcDecl)
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false

        // Determine promise return type
        let promiseReturnType: TypeSyntax = {
            if let returnType = returnTypeSyntax {
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Promise<\(returnType.description)>")))
            } else {
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Promise<Void>")))
            }
        }()

        // Create the function body that creates a promise
        let newBody = createPromiseFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters,
            isThrowing: isThrowing,
            returnType: returnTypeSyntax,
            isVoidReturn: isVoidReturn)

        // Create the new function signature
        let newSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: nil, // No async or throws for promise functions
            returnClause: ReturnClauseSyntax(type: promiseReturnType))

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

    /// Creates the function body that creates a Promise from an async function
    private static func createPromiseFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isThrowing: Bool,
        returnType: TypeSyntax?,
        isVoidReturn: Bool)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original async function with self.
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)),
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
        let taskStatements =
            if isThrowing {
                CodeBlockItemListSyntax {
                    // do {
                    CodeBlockItemSyntax(item: .stmt(StmtSyntax(
                        DoStmtSyntax(
                            body: CodeBlockSyntax(
                                statements: CodeBlockItemListSyntax {
                                    // let result = try await originalFunc() (only if not void)
                                    if !isVoidReturn {
                                        CodeBlockItemSyntax(item: .decl(DeclSyntax(
                                            VariableDeclSyntax(
                                                bindingSpecifier: .keyword(.let),
                                                bindings: PatternBindingListSyntax {
                                                    PatternBindingSyntax(
                                                        pattern: IdentifierPatternSyntax(
                                                            identifier: .identifier("result")),
                                                        initializer: InitializerClauseSyntax(value: innerCallExpr))
                                                }))))
                                    } else {
                                        // For void functions, just call the function
                                        CodeBlockItemSyntax(item: .expr(innerCallExpr))
                                    }
                                    // seal.fulfill(result) or seal.fulfill(())
                                    CodeBlockItemSyntax(item: .expr(ExprSyntax(
                                        FunctionCallExprSyntax(
                                            calledExpression: MemberAccessExprSyntax(
                                                base: DeclReferenceExprSyntax(baseName: .identifier("seal")),
                                                period: .periodToken(),
                                                name: .identifier("fulfill")),
                                            leftParen: .leftParenToken(),
                                            arguments: LabeledExprListSyntax {
                                                LabeledExprSyntax(
                                                    expression: isVoidReturn
                                                        ? ExprSyntax(TupleExprSyntax(elements: LabeledExprListSyntax()))
                                                        : ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("result"))))
                                            },
                                            rightParen: .rightParenToken()))))
                                }),
                            catchClauses: CatchClauseListSyntax {
                                CatchClauseSyntax(
                                    body: CodeBlockSyntax(
                                        statements: CodeBlockItemListSyntax {
                                            // seal.reject(error)
                                            CodeBlockItemSyntax(item: .expr(ExprSyntax(
                                                FunctionCallExprSyntax(
                                                    calledExpression: MemberAccessExprSyntax(
                                                        base: DeclReferenceExprSyntax(baseName: .identifier("seal")),
                                                        period: .periodToken(),
                                                        name: .identifier("reject")),
                                                    leftParen: .leftParenToken(),
                                                    arguments: LabeledExprListSyntax {
                                                        LabeledExprSyntax(
                                                            expression: DeclReferenceExprSyntax(
                                                                baseName: .identifier("error")))
                                                    },
                                                    rightParen: .rightParenToken()))))
                                        }))
                            }))))
                }
            } else {
                CodeBlockItemListSyntax {
                    // let result = await originalFunc() (only if not void)
                    if !isVoidReturn {
                        CodeBlockItemSyntax(item: .decl(DeclSyntax(
                            VariableDeclSyntax(
                                bindingSpecifier: .keyword(.let),
                                bindings: PatternBindingListSyntax {
                                    PatternBindingSyntax(
                                        pattern: IdentifierPatternSyntax(identifier: .identifier("result")),
                                        initializer: InitializerClauseSyntax(value: innerCallExpr))
                                }))))
                    } else {
                        // For void functions, just call the function
                        CodeBlockItemSyntax(item: .expr(innerCallExpr))
                    }
                    // seal.fulfill(result) or seal.fulfill(())
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(
                        FunctionCallExprSyntax(
                            calledExpression: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("seal")),
                                period: .periodToken(),
                                name: .identifier("fulfill")),
                            leftParen: .leftParenToken(),
                            arguments: LabeledExprListSyntax {
                                LabeledExprSyntax(
                                    expression: isVoidReturn
                                        ? ExprSyntax(TupleExprSyntax(elements: LabeledExprListSyntax()))
                                        : ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("result"))))
                            },
                            rightParen: .rightParenToken()))))
                }
            }

        // Create the Task call
        let taskCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Task")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken(),
            trailingClosure: ClosureExprSyntax(
                statements: taskStatements))

        // Create the Promise closure that takes a seal parameter
        let promiseClosure = ClosureExprSyntax(
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax {
                        ClosureShorthandParameterSyntax(name: .identifier("seal"))
                    })),
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(ExprSyntax(taskCall)))
            })

        // Create the Promise call
        let promiseCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Promise")),
            leftParen: nil,
            arguments: LabeledExprListSyntax(),
            rightParen: nil,
            trailingClosure: promiseClosure)

        // Create the return statement with promise
        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(
                    ReturnStmtSyntax(expression: ExprSyntax(promiseCall)))))
            })
    }
}

// MARK: - AwaitlessPromiseMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessPromise macro
enum AwaitlessPromiseMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitlessPromise can only be applied to functions"
    case requiresAsync = "@AwaitlessPromise requires the function to be 'async'"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessPromiseMacros", id: rawValue)
    }
}