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
        var availability: AwaitlessAvailability? = .deprecated() // Default to deprecated

        if case let .argumentList(arguments) = node.arguments {
            for argument in arguments {
                let labeledExpr = argument
                if labeledExpr.label?.text == "prefix",
                   let stringLiteral = labeledExpr.expression.as(StringLiteralExprSyntax.self)
                {
                    prefix = stringLiteral.segments.description
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                } else if labeledExpr.label == nil,
                          let availabilityExpr = labeledExpr.expression.as(MemberAccessExprSyntax.self)
                {
                    availability = parseAvailability(from: availabilityExpr)
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

        // Create the withCheckedThrowingContinuation call
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
        
        // Create the parameter for the continuation closure
        let continuationParam = ClosureParameterClauseSyntax(
            parameters: ClosureParameterListSyntax([
                ClosureParameterSyntax(firstName: .identifier("continuation"))
            ]))

        // Create the function call to the original method with completion handler
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

    /// Checks if a function has a completion handler parameter
    private static func hasCompletionHandlerParameter(_ funcDecl: FunctionDeclSyntax) -> Bool {
        for param in funcDecl.signature.parameterClause.parameters {
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