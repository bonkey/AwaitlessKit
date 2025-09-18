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

// MARK: - AwaitableMacro

/// A macro that generates an async/await version of a PromiseKit Promise function.
/// This macro creates a twin function with specified prefix that wraps the original
/// Promise function and converts it to async/await using Promise.value.
public struct AwaitfulMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        if declaration.is(ProtocolDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) {
            return [] // Protocols and classes are handled by MemberMacro and ExtensionMacro
        }
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitfulMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // Check if the function returns Promise<T>
        guard let returnClause = funcDecl.signature.returnClause,
              isPromiseReturnType(returnClause.type) else {
            let diagnostic = Diagnostic(
                node: Syntax(funcDecl.name),
                message: AwaitfulMacroDiagnostic.requiresPromiseReturn)
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

        let generatedDecl = DeclSyntax(Self.createAsyncFunction(
            from: funcDecl,
            prefix: prefix,
            availability: availability))
        return [generatedDecl]
    }

    /// Creates an async version of the provided Promise function
    private static func createAsyncFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract Promise inner type from return clause
        let promiseInnerType = extractPromiseInnerType(from: funcDecl.signature.returnClause!)

        // Create async function signature
        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: ReturnClauseSyntax(type: promiseInnerType))

        // Create function body that awaits the Promise
        let newBody = createAsyncFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters)

        // Create attributes for the new function
        var attributes = filterAttributes(funcDecl.attributes)

        // Add availability attribute with configurable default message
        if let availability {
            let defaultMessage = "PromiseKit support is deprecated; use async function instead"
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

    /// Creates the function body that awaits the Promise
    private static func createAsyncFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original Promise function
        let promiseCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken())

        // Add .async() to await the Promise result
        let awaitableExpr = MemberAccessExprSyntax(
            base: ExprSyntax(promiseCallExpr),
            period: .periodToken(),
            name: .identifier("async"))

        // Call .async() method
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: ExprSyntax(awaitableExpr),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken())

        // Add try await
        let tryAwaitExpr = TryExprSyntax(
            expression: AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr)))

        // Create return statement
        let returnStmt = ReturnStmtSyntax(expression: ExprSyntax(tryAwaitExpr))

        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
            })
    }

    /// Checks if a type is Promise<T>
    private static func isPromiseReturnType(_ type: TypeSyntax) -> Bool {
        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "Promise" {
            return true
        }
        return false
    }

    /// Extracts the inner type T from Promise<T>
    private static func extractPromiseInnerType(from returnClause: ReturnClauseSyntax) -> TypeSyntax {
        let returnType = returnClause.type
        
        if let identifierType = returnType.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "Promise",
           let genericArguments = identifierType.genericArgumentClause {
            if let firstArg = genericArguments.arguments.first {
                return firstArg.argument
            }
        }
        
        // Fallback to Void if we can't extract the inner type
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
    }
}

// MARK: - AwaitfulMacroDiagnostic

/// Diagnostics for errors related to the Awaitful macro
enum AwaitfulMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@Awaitful can only be applied to functions"
    case requiresPromiseReturn = "@Awaitful requires the function to return a Promise<T>"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessPromiseMacros", id: rawValue)
    }
}

