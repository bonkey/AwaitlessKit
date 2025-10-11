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

// MARK: - AwaitableCompletionMacro

/// A macro that generates an async/await version of a completion handler function.
/// This macro creates a twin function with specified prefix that wraps the original
/// completion handler function and converts it to async/await using withCheckedThrowingContinuation.
public struct AwaitableCompletionMacro: PeerMacro {
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
                message: AwaitableCompletionMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // Check if the function has a completion handler parameter
        guard hasCompletionHandlerParameter(funcDecl) else {
            let diagnostic = Diagnostic(
                node: Syntax(funcDecl.name),
                message: AwaitableCompletionMacroDiagnostic.requiresCompletionHandler)
            context.diagnose(diagnostic)
            return []
        }

        var prefix = ""
        var availability: AwaitlessAvailability? = nil // No default availability

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

        let generatedDecl = DeclSyntax(createAsyncFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability))
        return [generatedDecl]
    }

    /// Creates an async version of the provided completion handler function
    private static func createAsyncFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract completion handler parameter information
        let (parametersWithoutCompletion, resultType, isVoidResult) = extractCompletionInfo(from: funcDecl)

        // Create async function signature
        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(parameters: parametersWithoutCompletion),
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: isVoidResult ? nil : ReturnClauseSyntax(type: resultType))

        // Create function body that uses withCheckedThrowingContinuation
        let newBody = createAsyncFunctionBody(
            originalFuncName: originalFuncName,
            parameters: parametersWithoutCompletion,
            isVoidResult: isVoidResult)

        // Create attributes for the new function
        var attributes = filterCompletionAttributes(funcDecl.attributes)

        // Add availability attribute with configurable default message
        if let availability {
            let defaultMessage = "Completion handler support is deprecated; use async function instead"
            let availabilityAttr = createAvailabilityAttributeWithMessage(
                originalFuncName: originalFuncName,
                availability: availability,
                defaultMessage: defaultMessage)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
        }

        // Create the new function
        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: funcDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName),
            genericParameterClause: funcDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: newBody)
    }

    /// Creates the function body that uses withCheckedThrowingContinuation
    private static func createAsyncFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        isVoidResult: Bool)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the withCheckedThrowingContinuation call with trailing closure
        let continuationBody = createContinuationBody(
            originalFuncName: originalFuncName,
            argumentList: argumentList,
            isVoidResult: isVoidResult)

        let continuationCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("withCheckedThrowingContinuation")),
            trailingClosure: continuationBody.as(ClosureExprSyntax.self)) {
            LabeledExprListSyntax([])
        }

        // Add try await
        let tryAwaitExpr = TryExprSyntax(
            expression: AwaitExprSyntax(expression: ExprSyntax(continuationCall)))

        // Create return statement if needed
        let statement = if isVoidResult {
            StmtSyntax(ExpressionStmtSyntax(expression: ExprSyntax(tryAwaitExpr)))
        } else {
            StmtSyntax(ReturnStmtSyntax(expression: ExprSyntax(tryAwaitExpr)))
        }

        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(statement))
            })
    }

    /// Creates the continuation closure body
    private static func createContinuationBody(
        originalFuncName: String,
        argumentList: LabeledExprListSyntax,
        isVoidResult: Bool) -> ExprSyntax {
        
        // Create the function call to the original method with completion handler
        let completionClosure = createCompletionClosure(isVoidResult: isVoidResult)
        
        var callArguments = Array(argumentList)
        
        // If there are existing arguments, add a trailing comma to the last one
        if !callArguments.isEmpty {
            let lastIndex = callArguments.count - 1
            let lastArg = callArguments[lastIndex]
            callArguments[lastIndex] = LabeledExprSyntax(
                label: lastArg.label,
                colon: lastArg.colon,
                expression: lastArg.expression,
                trailingComma: .commaToken()
            )
        }
        
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
            leftBrace: .leftBraceToken(),
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax([
                        ClosureShorthandParameterSyntax(name: .identifier("continuation"))
                    ])
                )
            ),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(ExpressionStmtSyntax(expression: ExprSyntax(originalCall)))))
            ]),
            rightBrace: .rightBraceToken()))
    }

    /// Creates the completion closure that resumes the continuation
    private static func createCompletionClosure(isVoidResult: Bool) -> ExprSyntax {
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
            leftBrace: .leftBraceToken(),
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax([
                        ClosureShorthandParameterSyntax(name: .identifier("result"))
                    ])
                )
            ),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(ExpressionStmtSyntax(expression: ExprSyntax(resumeCall)))))
            ]),
            rightBrace: .rightBraceToken()))
    }

    /// Checks if a function has a completion handler parameter
    private static func hasCompletionHandlerParameter(_ funcDecl: FunctionDeclSyntax) -> Bool {
        for param in funcDecl.signature.parameterClause.parameters {
            // Check if parameter name suggests it's a completion handler
            if param.firstName.text.lowercased().contains("completion") {
                // Try to get the function type, handling @escaping attributes
                var type = param.type
                // If the type has @escaping, strip it to get the underlying function type
                if let attributedType = type.as(AttributedTypeSyntax.self),
                   let baseType = attributedType.baseType.as(FunctionTypeSyntax.self) {
                    type = TypeSyntax(baseType)
                }
                
                if let functionType = type.as(FunctionTypeSyntax.self) {
                    // Check if it takes a Result<T, Error> parameter
                    if isResultType(functionType.parameters.first?.type) {
                        return true
                    }
                    // Also accept any function type if the parameter name suggests completion
                    return true
                }
            } else {
                // Also check if any parameter has a Result<T, Error> function type
                var type = param.type
                if let attributedType = type.as(AttributedTypeSyntax.self),
                   let baseType = attributedType.baseType.as(FunctionTypeSyntax.self) {
                    type = TypeSyntax(baseType)
                }
                
                if let functionType = type.as(FunctionTypeSyntax.self),
                   isResultType(functionType.parameters.first?.type) {
                    return true
                }
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

    /// Extracts completion handler information from function
    private static func extractCompletionInfo(from funcDecl: FunctionDeclSyntax) -> (FunctionParameterListSyntax, TypeSyntax, Bool) {
        var parametersWithoutCompletion: [FunctionParameterSyntax] = []
        var resultType: TypeSyntax = TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
        var isVoidResult = true

        for param in funcDecl.signature.parameterClause.parameters {
            let paramName = param.firstName.text.lowercased()
            // Check if this is a completion parameter
            if paramName.contains("completion") {
                // Try to get the function type, handling @escaping attributes
                var type = param.type
                if let attributedType = type.as(AttributedTypeSyntax.self),
                   let baseType = attributedType.baseType.as(FunctionTypeSyntax.self) {
                    type = TypeSyntax(baseType)
                }
                
                if let functionType = type.as(FunctionTypeSyntax.self) {
                    // This is the completion parameter, extract the result type
                    if let firstParam = functionType.parameters.first?.type,
                       let identifierType = firstParam.as(IdentifierTypeSyntax.self),
                       identifierType.name.text == "Result",
                       let genericArgs = identifierType.genericArgumentClause,
                       let successType = genericArgs.arguments.first?.argument {
                        resultType = successType
                        isVoidResult = successType.description.trimmingCharacters(in: .whitespacesAndNewlines) == "Void"
                    }
                }
                // Skip adding completion parameter to parametersWithoutCompletion
            } else {
                // Create a new parameter without trailing comma
                let newParam = FunctionParameterSyntax(
                    attributes: param.attributes,
                    modifiers: param.modifiers,
                    firstName: param.firstName,
                    secondName: param.secondName,
                    colon: param.colon,
                    type: param.type,
                    defaultValue: param.defaultValue,
                    trailingComma: nil  // Remove trailing comma
                )
                parametersWithoutCompletion.append(newParam)
            }
        }

        return (FunctionParameterListSyntax(parametersWithoutCompletion), resultType, isVoidResult)
    }

    
    /// Creates availability attribute with message
    private static func createAvailabilityAttributeWithMessage(
        originalFuncName: String,
        availability: AwaitlessAvailability,
        defaultMessage: String) -> AttributeSyntax {
        
        let message: String
        let renamed: String? = originalFuncName
        
        switch availability {
        case .deprecated(let customMessage):
            message = customMessage ?? defaultMessage
        case .unavailable(let customMessage):
            message = customMessage ?? defaultMessage
        }
        
        let messageArg = LabeledExprSyntax(
            label: .identifier("message"),
            colon: .colonToken(),
            expression: StringLiteralExprSyntax(content: message),
            trailingComma: .commaToken())
        
        let renamedArg = LabeledExprSyntax(
            label: .identifier("renamed"),
            colon: .colonToken(),
            expression: StringLiteralExprSyntax(content: renamed ?? originalFuncName))
        
        let availabilityType: String
        switch availability {
        case .deprecated:
            availabilityType = "deprecated"
        case .unavailable:
            availabilityType = "unavailable"
        }
        
        let arguments = LabeledExprListSyntax([
            LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .binaryOperator("*")), trailingComma: .commaToken()),
            LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier(availabilityType)), trailingComma: .commaToken()),
            messageArg,
            renamedArg
        ])
        
        return AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier("available")),
            leftParen: .leftParenToken(),
            arguments: .argumentList(arguments),
            rightParen: .rightParenToken())
    }
}

// MARK: - Helper Functions

/// Filters out the AwaitableCompletion attributes from the attributes list
func filterCompletionAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
    attributes.filter { attr in
        if case let .attribute(actualAttr) = attr,
           let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
           attrName.name.text == "AwaitableCompletion"
        {
            return false
        }
        return true
    }
}

// MARK: - AwaitableCompletionMacroDiagnostic

/// Diagnostics for errors related to the AwaitableCompletion macro
enum AwaitableCompletionMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitableCompletion can only be applied to functions"
    case requiresCompletionHandler = "@AwaitableCompletion requires the function to have a completion handler parameter"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessKitMacros", id: rawValue)
    }
}