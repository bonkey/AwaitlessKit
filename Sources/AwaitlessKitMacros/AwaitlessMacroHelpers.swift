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

// MARK: - Configuration Resolution

/// Resolves configuration using the four-level precedence hierarchy:
/// 1. Method parameters (highest priority)
/// 2. Type-level @AwaitlessConfig 
/// 3. Process-level AwaitlessConfig.currentDefaults
/// 4. Built-in defaults (lowest priority)
func resolveConfiguration(
    methodPrefix: String?,
    methodAvailability: AwaitlessAvailability?,
    methodDelivery: AwaitlessDelivery?,
    methodStrategy: AwaitlessSynchronizationStrategy?,
    typeDeclaration: (any DeclGroupSyntax)?,
    builtInPrefix: String = "awaitless",
    builtInAvailability: AwaitlessAvailability? = nil,
    builtInDelivery: AwaitlessDelivery = .current,
    builtInStrategy: AwaitlessSynchronizationStrategy = .concurrent
) -> AwaitlessConfigData {
    
    // Step 1: Check for type-level configuration
    var typeConfig: AwaitlessConfigData? = nil
    if let typeDecl = typeDeclaration {
        typeConfig = extractTypeConfiguration(from: typeDecl)
    }
    
    // Step 2: Get process-level configuration (this would normally access AwaitlessConfig.currentDefaults)
    // For now, we'll create an empty one since macros can't access runtime state during compilation
    let processConfig = AwaitlessConfigData()
    
    // Step 3: Resolve with precedence hierarchy
    return AwaitlessConfigData(
        prefix: methodPrefix ?? typeConfig?.prefix ?? processConfig.prefix ?? builtInPrefix,
        availability: methodAvailability ?? typeConfig?.availability ?? processConfig.availability ?? builtInAvailability,
        delivery: methodDelivery ?? typeConfig?.delivery ?? processConfig.delivery ?? builtInDelivery,
        strategy: methodStrategy ?? typeConfig?.strategy ?? processConfig.strategy ?? builtInStrategy
    )
}

/// Extracts configuration from a type's __awaitlessConfig property if it exists
private func extractTypeConfiguration(from typeDecl: any DeclGroupSyntax) -> AwaitlessConfigData? {
    // Look for a static property named __awaitlessConfig
    for member in typeDecl.memberBlock.members {
        if let varDecl = member.decl.as(VariableDeclSyntax.self),
           varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
           let binding = varDecl.bindings.first,
           let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
           pattern.identifier.text == "__awaitlessConfig" {
            
            // We found the config property, but extracting the actual values from
            // the AST is complex. For the MVP, we'll return a basic config.
            // In a full implementation, we'd parse the initializer expression.
            return AwaitlessConfigData()
        }
    }
    return nil
}

// MARK: - Shared Helper Functions

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

/// Filters out the Awaitless attribute from the attributes list
func filterAttributes(_ attributes: AttributeListSyntax) -> AttributeListSyntax {
    attributes.filter { attr in
        if case let .attribute(actualAttr) = attr,
           let attrName = actualAttr.attributeName.as(IdentifierTypeSyntax.self),
           attrName.name.text == "Awaitless" || attrName.name.text == "AwaitlessPublisher" || attrName.name.text == "AwaitlessCompletion"
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
