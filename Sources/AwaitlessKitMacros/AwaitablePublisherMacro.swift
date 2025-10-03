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

// MARK: - AwaitablePublisherMacro

/// A macro that generates an async/await version of a Combine Publisher function.
/// This macro creates a twin function with specified prefix that wraps the original
/// Publisher function and converts it to async/await using Publisher.async().
public struct AwaitablePublisherMacro: PeerMacro {
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
                message: AwaitablePublisherMacroDiagnostic.requiresFunction)
            context.diagnose(diagnostic)
            return []
        }

        // Check if the function returns Publisher<T, E>
        guard let returnClause = funcDecl.signature.returnClause,
              isPublisherReturnType(returnClause.type) else {
            let diagnostic = Diagnostic(
                node: Syntax(funcDecl.name),
                message: AwaitablePublisherMacroDiagnostic.requiresPublisherReturn)
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

    /// Creates an async version of the provided Publisher function
    private static func createAsyncFunction(
        from funcDecl: FunctionDeclSyntax,
        prefix: String,
        availability: AwaitlessAvailability?)
        -> FunctionDeclSyntax
    {
        let originalFuncName = funcDecl.name.text
        let newFuncName = prefix + originalFuncName

        // Extract Publisher inner types from return clause
        let (outputType, errorType) = extractPublisherInnerTypes(from: funcDecl.signature.returnClause!)

        // Create async function signature
        let asyncSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async),
                throwsClause: errorType == "Never" ? nil : ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
            returnClause: ReturnClauseSyntax(type: outputType))

        // Create function body that awaits the Publisher
        let newBody = createAsyncFunctionBody(
            originalFuncName: originalFuncName,
            parameters: funcDecl.signature.parameterClause.parameters,
            errorType: errorType)

        // Create attributes for the new function
        var attributes = filterPublisherAttributes(funcDecl.attributes)

        // Add availability attribute with configurable default message
        if let availability {
            let defaultMessage = "Combine support is deprecated; use async function instead"
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

    /// Creates the function body that awaits the Publisher
    private static func createAsyncFunctionBody(
        originalFuncName: String,
        parameters: FunctionParameterListSyntax,
        errorType: String)
        -> CodeBlockSyntax
    {
        // Map parameters from the original function to argument expressions
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original Publisher function
        let publisherCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: .identifier(originalFuncName)),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken())

        // Add .async() to await the Publisher result (or .value for Never error types)
        let awaitableExpr = MemberAccessExprSyntax(
            base: ExprSyntax(publisherCallExpr),
            period: .periodToken(),
            name: .identifier(errorType == "Never" ? "value" : "async"))

        // Call .async() or .value method
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: ExprSyntax(awaitableExpr),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(),
            rightParen: .rightParenToken())

        // Add try await or just await depending on error type
        let awaitExpr = AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr))
        let finalExpr = errorType == "Never" ? 
            ExprSyntax(awaitExpr) :
            ExprSyntax(TryExprSyntax(expression: awaitExpr))

        // Create return statement
        let returnStmt = ReturnStmtSyntax(expression: finalExpr)

        return CodeBlockSyntax(
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
            })
    }

    /// Checks if a type is Publisher<T, E>
    private static func isPublisherReturnType(_ type: TypeSyntax) -> Bool {
        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "AnyPublisher" || identifierType.name.text == "Publisher" {
            return true
        }
        return false
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
        
        // Fallback
        return (TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void"))), "Error")
    }

    /// Parse availability from expression
    private static func parseAvailability(from expr: MemberAccessExprSyntax) -> AwaitlessAvailability? {
        switch expr.declName.baseName.text {
        case "deprecated":
            return .deprecated()
        case "unavailable":
            return .unavailable()
        default:
            return nil
        }
    }
}

// MARK: - Helper Functions

/// Filters out the AwaitablePublisher attributes from the attributes list
func filterPublisherAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
    attributes.filter { attr in
        if case let .attribute(actualAttr) = attr,
           let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
           attrName.name.text == "AwaitablePublisher"
        {
            return false
        }
        return true
    }
}

/// Creates availability attribute with message
func createAvailabilityAttributeWithMessage(
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
        expression: StringLiteralExprSyntax(content: message))
    
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
        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .binaryOperator("*"))),
        LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier(availabilityType))),
        messageArg,
        renamedArg
    ])
    
    return AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("available")),
        leftParen: .leftParenToken(),
        arguments: .argumentList(arguments),
        rightParen: .rightParenToken())
}

// MARK: - AwaitablePublisherMacroDiagnostic

/// Diagnostics for errors related to the AwaitablePublisher macro
enum AwaitablePublisherMacroDiagnostic: String, DiagnosticMessage {
    case requiresFunction = "@AwaitablePublisher can only be applied to functions"
    case requiresPublisherReturn = "@AwaitablePublisher requires the function to return a Publisher<T, E>"

    var severity: DiagnosticSeverity {
        .error
    }

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessKitMacros", id: rawValue)
    }
}