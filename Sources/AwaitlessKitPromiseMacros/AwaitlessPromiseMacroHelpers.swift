//
// Copyright (c) 2025 Daniel Bauke
//

import AwaitlessCore
import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Shared Helper Functions for PromiseKit macros

/// Creates argument list from function parameters
func createArgumentList(from parameters: FunctionParameterListSyntax) -> LabeledExprListSyntax {
    let callArguments = parameters.enumerated().map { index, param in
        // Get the argument label (external name) and parameter name (internal name)
        let argumentLabel = param.firstName
        let parameterName = param.secondName ?? param.firstName

        let isInout = param.type.description.contains("inout")
        let expression =
            if isInout {
                ExprSyntax(InOutExprSyntax(expression: DeclReferenceExprSyntax(baseName: parameterName.trimmed)))
            } else {
                ExprSyntax(DeclReferenceExprSyntax(baseName: parameterName.trimmed))
            }

        // Add trailing comma for all except the last parameter
        let trailingComma: TokenSyntax? = index < parameters.count - 1 ? .commaToken() : nil
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

/// Filters out the AwaitlessPromise attribute from the attributes list
func filterAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
    attributes.filter { attr in
        if case let .attribute(actualAttr) = attr,
           let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
           attrName.name.text == "AwaitlessPromise"
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

        if let simpleType = returnType.as(IdentifierTypeSyntax.self), simpleType.name.text == "Void" {
            return (returnType, true)
        }
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
        let message = messageOpt ?? "Use async \(originalFuncName) function instead"
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
        let message = messageOpt ?? "This synchronous version of \(originalFuncName) is unavailable"
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