//
// Copyright (c) 2025 Daniel Bauke
//

public import SwiftSyntax
public import SwiftSyntaxMacros
import AwaitlessCore
import SwiftDiagnostics
import Foundation

// MARK: - AwaitableMacro

/// Macro that generates async method signatures for protocols with Publisher-returning methods and completion handler methods
public struct AwaitableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        // Handle protocol declarations
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitableMacroDiagnostic.requiresProtocol)
            context.diagnose(diagnostic)
            return []
        }

        // For protocols, we create async versions of Publisher/completion methods as member declarations
        var memberDeclarations: [DeclSyntax] = []

        // Process all members to find Publisher-returning functions or completion handler functions
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                if isPublisherReturningFunction(functionDecl) {
                    // Create async version of Publisher function
                    let asyncFunction = createAsyncFunctionSignatureFromPublisher(from: functionDecl)
                    memberDeclarations.append(DeclSyntax(asyncFunction))
                } else if hasCompletionHandlerParameter(functionDecl) {
                    // Create async version of completion handler function
                    let asyncFunction = createAsyncFunctionSignatureFromCompletion(from: functionDecl)
                    memberDeclarations.append(DeclSyntax(asyncFunction))
                }
            }
        }

        return memberDeclarations
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext) throws
        -> [ExtensionDeclSyntax]
    {
        // Extract configuration from the attribute
        let (prefix, availability, extensionGeneration) = parseAttributeArguments(from: node)

        // Only generate extensions if explicitly enabled
        guard extensionGeneration == .enabled else {
            return []
        }

        // Handle protocol declarations
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            return []
        }

        var extensionFunctions: [FunctionDeclSyntax] = []

        // Process all members to find Publisher-returning functions or completion handler functions
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                if isPublisherReturningFunction(functionDecl) {
                    // Create async implementation for Publisher function
                    let asyncFunction = createAsyncFunctionImplementationFromPublisher(
                        from: functionDecl,
                        prefix: prefix,
                        availability: availability)
                    extensionFunctions.append(asyncFunction)
                } else if hasCompletionHandlerParameter(functionDecl) {
                    // Create async implementation for completion handler function
                    let asyncFunction = createAsyncFunctionImplementationFromCompletion(
                        from: functionDecl,
                        prefix: prefix,
                        availability: availability)
                    extensionFunctions.append(asyncFunction)
                }
            }
        }

        if extensionFunctions.isEmpty {
            return []
        }

        let extensionDecl = ExtensionDeclSyntax(
            extendedType: type,
            memberBlock: MemberBlockSyntax(
                members: MemberBlockItemListSyntax(
                    extensionFunctions.map { MemberBlockItemSyntax(decl: DeclSyntax($0)) }
                )
            )
        )

        return [extensionDecl]
    }

    // MARK: - Publisher Function Helpers

    /// Checks if a function returns a Publisher
    private static func isPublisherReturningFunction(_ functionDecl: FunctionDeclSyntax) -> Bool {
        guard let returnClause = functionDecl.signature.returnClause else { return false }
        return isPublisherReturnType(returnClause.type)
    }

    /// Checks if a type is Publisher<T, E>
    private static func isPublisherReturnType(_ type: TypeSyntax) -> Bool {
        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "AnyPublisher" || identifierType.name.text == "Publisher" {
            return true
        }
        return false
    }

    /// Creates an async function signature from a Publisher function
    private static func createAsyncFunctionSignatureFromPublisher(from functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        let (outputType, errorType) = extractPublisherInnerTypes(from: functionDecl.signature.returnClause!)

        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: functionDecl.signature.parameterClause,
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: errorType == "Never" ? nil : ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: ReturnClauseSyntax(type: outputType))

        return FunctionDeclSyntax(
            modifiers: functionDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: functionDecl.name,
            genericParameterClause: functionDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: functionDecl.genericWhereClause)
    }

    /// Creates an async function implementation from a Publisher function
    private static func createAsyncFunctionImplementationFromPublisher(
        from functionDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?) -> FunctionDeclSyntax {
        
        let originalFuncName = functionDecl.name.text
        let newFuncName = prefix + originalFuncName
        let (outputType, errorType) = extractPublisherInnerTypes(from: functionDecl.signature.returnClause!)

        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: functionDecl.signature.parameterClause,
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: errorType == "Never" ? nil : ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: ReturnClauseSyntax(type: outputType))

        // Create function body
        let argumentList = createArgumentList(from: functionDecl.signature.parameterClause.parameters)
        let publisherCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken())

        let awaitableExpr = MemberAccessExprSyntax(
            base: ExprSyntax(publisherCallExpr),
            period: .periodToken(),
            name: .identifier(errorType == "Never" ? "value" : "async"))

        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: ExprSyntax(awaitableExpr),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken())

        let awaitExpr = AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr))
        let finalExpr = errorType == "Never" ? 
            ExprSyntax(awaitExpr) :
            ExprSyntax(TryExprSyntax(expression: awaitExpr))

        let returnStmt = ReturnStmtSyntax(expression: finalExpr)
        let newBody = CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
            })

        // Create attributes
        var attributes = AttributeListSyntax()
        if let availability {
            let defaultMessage = "Combine support is deprecated; use async function instead"
            let availabilityAttr = createAvailabilityAttributeWithMessage(
                originalFuncName: originalFuncName,
                availability: availability,
                defaultMessage: defaultMessage)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
        }

        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: [DeclModifierSyntax(name: .keyword(.public))],
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName.isEmpty ? originalFuncName : newFuncName),
            genericParameterClause: functionDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: functionDecl.genericWhereClause,
            body: newBody)
    }

    /// Extracts the inner types T and E from Publisher<T, E>
    private static func extractPublisherInnerTypes(from returnClause: ReturnClauseSyntax) -> (TypeSyntax, String) {
        let returnType = returnClause.type
        
        if let identifierType = returnType.as(IdentifierTypeSyntax.self),
           (identifierType.name.text == "AnyPublisher" || identifierType.name.text == "Publisher"),
           let genericArguments = identifierType.genericArgumentClause {
            let args = Array(genericArguments.arguments)
            let outputType = args.first?.argument ?? TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
            let errorType = args.count > 1 ? args[1].argument.description.trimmingCharacters(in: .whitespacesAndNewlines) : "Error"
            return (outputType, errorType)
        }
        
        return (TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void"))), "Error")
    }

    // MARK: - Completion Handler Function Helpers

    /// Checks if a function has a completion handler parameter
    private static func hasCompletionHandlerParameter(_ functionDecl: FunctionDeclSyntax) -> Bool {
        for param in functionDecl.signature.parameterClause.parameters {
            if let functionType = param.type.as(FunctionTypeSyntax.self),
               param.firstName.text.lowercased().contains("completion") ||
               isResultType(functionType.parameters.first?.type) {
                return true
            }
        }
        return false
    }

    /// Checks if a type is Result<T, Error>
    private static func isResultType(_ type: TypeSyntax?) -> Bool {
        guard let type = type,
              let identifierType = type.as(IdentifierTypeSyntax.self) else {
            return false
        }
        return identifierType.name.text == "Result"
    }

    /// Creates an async function signature from a completion handler function
    private static func createAsyncFunctionSignatureFromCompletion(from functionDecl: FunctionDeclSyntax) -> FunctionDeclSyntax {
        let (parametersWithoutCompletion, resultType, isVoidResult) = extractCompletionInfo(from: functionDecl)

        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(parameters: parametersWithoutCompletion),
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: isVoidResult ? nil : ReturnClauseSyntax(type: resultType))

        return FunctionDeclSyntax(
            modifiers: functionDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: functionDecl.name,
            genericParameterClause: functionDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: functionDecl.genericWhereClause)
    }

    /// Creates an async function implementation from a completion handler function
    private static func createAsyncFunctionImplementationFromCompletion(
        from functionDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?) -> FunctionDeclSyntax {
        
        let originalFuncName = functionDecl.name.text
        let newFuncName = prefix + originalFuncName
        let (parametersWithoutCompletion, resultType, isVoidResult) = extractCompletionInfo(from: functionDecl)

        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(parameters: parametersWithoutCompletion),
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: isVoidResult ? nil : ReturnClauseSyntax(type: resultType))

        // Create function body using withCheckedThrowingContinuation
        let argumentList = createArgumentList(from: parametersWithoutCompletion)
        let continuationBody = createContinuationBody(
            originalFuncName: originalFuncName,
            argumentList: argumentList,
            isVoidResult: isVoidResult)

        let continuationCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("withCheckedThrowingContinuation")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(expression: continuationBody)
            ]),
            rightParen: .rightParenToken())

        let tryAwaitExpr = TryExprSyntax(
            expression: AwaitExprSyntax(expression: ExprSyntax(continuationCall)))

        let statement = if isVoidResult {
            StmtSyntax(ExpressionStmtSyntax(expression: ExprSyntax(tryAwaitExpr)))
        } else {
            StmtSyntax(ReturnStmtSyntax(expression: ExprSyntax(tryAwaitExpr)))
        }

        let newBody = CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(statement))
            })

        // Create attributes
        var attributes = AttributeListSyntax()
        if let availability {
            let defaultMessage = "Completion handler support is deprecated; use async function instead"
            let availabilityAttr = createAvailabilityAttributeWithMessage(
                originalFuncName: originalFuncName,
                availability: availability,
                defaultMessage: defaultMessage)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
        }

        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: [DeclModifierSyntax(name: .keyword(.public))],
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName.isEmpty ? originalFuncName : newFuncName),
            genericParameterClause: functionDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: functionDecl.genericWhereClause,
            body: newBody)
    }

    /// Extracts completion handler information from function
    private static func extractCompletionInfo(from funcDecl: FunctionDeclSyntax) -> (FunctionParameterListSyntax, TypeSyntax, Bool) {
        var parametersWithoutCompletion: [FunctionParameterSyntax] = []
        var resultType: TypeSyntax = TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
        var isVoidResult = true

        for param in funcDecl.signature.parameterClause.parameters {
            if let functionType = param.type.as(FunctionTypeSyntax.self),
               param.firstName.text.lowercased().contains("completion") {
                // This is the completion parameter, extract the result type
                if let firstParam = functionType.parameters.first?.type,
                   let identifierType = firstParam.as(IdentifierTypeSyntax.self),
                   identifierType.name.text == "Result",
                   let genericArgs = identifierType.genericArgumentClause,
                   let successType = genericArgs.arguments.first?.argument {
                    resultType = successType
                    isVoidResult = successType.description.trimmingCharacters(in: .whitespacesAndNewlines) == "Void"
                }
            } else {
                parametersWithoutCompletion.append(param)
            }
        }

        return (FunctionParameterListSyntax(parametersWithoutCompletion), resultType, isVoidResult)
    }

    /// Creates the continuation closure body
    private static func createContinuationBody(
        originalFuncName: String,
        argumentList: LabeledExprListSyntax,
        isVoidResult: Bool) -> ExprSyntax {
        
        let continuationParam = ClosureParameterClauseSyntax(
            parameters: ClosureParameterListSyntax([
                ClosureParameterSyntax(firstName: .identifier("continuation"))
            ]))

        let completionClosure = createCompletionClosure(isVoidResult: isVoidResult)
        
        var callArguments = Array(argumentList)
        callArguments.append(LabeledExprSyntax(
            label: .identifier("completion"),
            colon: .colonToken(),
            expression: completionClosure))

        let originalCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(callArguments),
            rightParen: .rightParenToken())

        return ExprSyntax(ClosureExprSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            signature: ClosureSignatureSyntax(parameterClause: .parameterClause(continuationParam)),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(ExpressionStmtSyntax(expression: ExprSyntax(originalCall)))))
            ]),
            rightBrace: .rightBraceToken(leadingTrivia: .newline)))
    }

    /// Creates the completion closure that resumes the continuation
    private static func createCompletionClosure(isVoidResult: Bool) -> ExprSyntax {
        let resultParam = ClosureParameterClauseSyntax(
            parameters: ClosureParameterListSyntax([
                ClosureParameterSyntax(firstName: .identifier("result"))
            ]))

        let resumeCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("continuation")),
                period: .periodToken(),
                name: .identifier("resume")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    label: .identifier("with"),
                    colon: .colonToken(),
                    expression: DeclReferenceExprSyntax(baseName: .identifier("result")))
            ]),
            rightParen: .rightParenToken())

        return ExprSyntax(ClosureExprSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            signature: ClosureSignatureSyntax(parameterClause: .parameterClause(resultParam)),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(ExpressionStmtSyntax(expression: ExprSyntax(resumeCall)))))
            ]),
            rightBrace: .rightBraceToken(leadingTrivia: .newline)))
    }

    // MARK: - Shared Helper Functions

    /// Parses attribute arguments
    private static func parseAttributeArguments(from node: AttributeSyntax) -> (String, AwaitlessAvailability?, AwaitlessableExtensionGeneration) {
        var prefix = ""
        var availability: AwaitlessAvailability? = .deprecated()
        var extensionGeneration: AwaitlessableExtensionGeneration = .enabled

        if case let .argumentList(arguments) = node.arguments {
            for argument in arguments {
                let labeledExpr = argument
                if labeledExpr.label?.text == "prefix",
                   let stringLiteral = labeledExpr.expression.as(StringLiteralExprSyntax.self) {
                    prefix = stringLiteral.segments.description.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                } else if labeledExpr.label?.text == "extensionGeneration",
                          let memberAccess = labeledExpr.expression.as(MemberAccessExprSyntax.self) {
                    switch memberAccess.declName.baseName.text {
                    case "enabled":
                        extensionGeneration = .enabled
                    case "disabled":
                        extensionGeneration = .disabled
                    default:
                        break
                    }
                } else if labeledExpr.label == nil,
                          let availabilityExpr = labeledExpr.expression.as(MemberAccessExprSyntax.self) {
                    availability = parseAvailability(from: availabilityExpr)
                }
            }
        }

        return (prefix, availability, extensionGeneration)
    }

    /// Parse availability from expression
    private static func parseAvailability(from expr: MemberAccessExprSyntax) -> AwaitlessAvailability? {
        switch expr.declName.baseName.text {
        case "deprecated":
            return .deprecated()
        case "unavailable":
            return .unavailable()
        // case "noasync":
            // return .noasync
        default:
            return nil
        }
    }
}

// MARK: - AwaitableMacroDiagnostic

/// Diagnostics for errors related to the Awaitable macro
enum AwaitableMacroDiagnostic: String, DiagnosticMessage {
    case requiresProtocol = "@Awaitable can only be applied to protocols"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessKitMacros", id: rawValue)
    }
}