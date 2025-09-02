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

// MARK: - Shared Helper Functions

/// Creates argument list from function parameters
func createArgumentList(from parameters: FunctionParameterListSyntax) -> LabeledExprListSyntax {
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
func filterAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
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
func extractReturnType(funcDecl: FunctionDeclSyntax) -> (TypeSyntax?, Bool) {
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

/// Creates an availability attribute for the function
func createAvailabilityAttribute(
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