//
// Copyright (c) 2025 Daniel Bauke
//

public import SwiftSyntax
public import SwiftSyntaxMacros
import AwaitlessCore
import SwiftDiagnostics
import Foundation

// MARK: - AwaitablePromiseProtocolMacro

/// Macro that generates async method signatures for protocols and classes with Promise-returning methods
public struct AwaitablePromiseProtocolMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        // Handle both protocol and class declarations
        var memberDeclarations: [DeclSyntax] = []

        // Extract configuration from the attribute
        let (prefix, availability) = parseAttributeArguments(from: node)

        // Process all members to find Promise-returning functions
        if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            for member in protocolDecl.memberBlock.members {
                if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                    if isPromiseReturningFunction(functionDecl) {
                        let asyncFunction = createAsyncFunctionSignature(
                            from: functionDecl, 
                            prefix: prefix, 
                            availability: availability)
                        memberDeclarations.append(DeclSyntax(asyncFunction))
                    }
                }
            }
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            for member in classDecl.memberBlock.members {
                if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                    if isPromiseReturningFunction(functionDecl) {
                        let asyncFunction = createAsyncFunctionSignature(
                            from: functionDecl, 
                            prefix: prefix, 
                            availability: availability)
                        memberDeclarations.append(DeclSyntax(asyncFunction))
                    }
                }
            }
        } else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitfulableMacroDiagnostic.requiresProtocolOrClass)
            context.diagnose(diagnostic)
            return []
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
        // Parse the extension generation configuration
        let extensionGeneration = parseExtensionGenerationArgument(from: node)

        // Only generate extensions if enabled (default is enabled)
        guard extensionGeneration == .enabled else {
            return []
        }

        // Extract configuration from the attribute
        let (prefix, availability) = parseAttributeArguments(from: node)

        // Generate extension with default implementations
        var extensionMembers: [MemberBlockItemSyntax] = []

        // Process all members to find Promise-returning functions
        if let protocolDecl = declaration.as(ProtocolDeclSyntax.self) {
            for member in protocolDecl.memberBlock.members {
                if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                    if isPromiseReturningFunction(functionDecl) {
                        let asyncFunction = createAsyncFunctionWithDefaultImplementation(
                            from: functionDecl, 
                            prefix: prefix, 
                            availability: availability)
                        extensionMembers.append(MemberBlockItemSyntax(decl: DeclSyntax(asyncFunction)))
                    }
                }
            }
        } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
            for member in classDecl.memberBlock.members {
                if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                    if isPromiseReturningFunction(functionDecl) {
                        let asyncFunction = createAsyncFunctionWithDefaultImplementation(
                            from: functionDecl, 
                            prefix: prefix, 
                            availability: availability)
                        extensionMembers.append(MemberBlockItemSyntax(decl: DeclSyntax(asyncFunction)))
                    }
                }
            }
        }

        // Only create extension if we have members to add
        guard !extensionMembers.isEmpty else {
            return []
        }

        let memberBlock = MemberBlockSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            members: MemberBlockItemListSyntax(extensionMembers),
            rightBrace: .rightBraceToken(leadingTrivia: .newline))

        let extensionDecl = ExtensionDeclSyntax(
            extensionKeyword: .keyword(.extension, leadingTrivia: .newline),
            extendedType: type,
            memberBlock: memberBlock)

        return [extensionDecl]
    }

    /// Checks if a function returns a Promise<T>
    private static func isPromiseReturningFunction(_ funcDecl: FunctionDeclSyntax) -> Bool {
        guard let returnClause = funcDecl.signature.returnClause else {
            return false
        }
        return isPromiseReturnType(returnClause.type)
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

    /// Creates an async function signature from a Promise-returning function declaration
    private static func createAsyncFunctionSignature(
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

        // Create attributes
        var attributes = AttributeListSyntax([])
        if let availability {
            let defaultMessage = "PromiseKit support is deprecated; use async function instead"
            let availabilityAttr = createAvailabilityAttributeWithMessage(
                originalFuncName: originalFuncName,
                availability: availability,
                defaultMessage: defaultMessage)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
        }

        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: funcDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName),
            genericParameterClause: funcDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: nil)
    }

    /// Creates an async function with default implementation using Promise.async()
    private static func createAsyncFunctionWithDefaultImplementation(
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

        // Generate parameter call for the Promise call
        let parameters = funcDecl.signature.parameterClause.parameters
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

        let body = CodeBlockSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt))),
            ]),
            rightBrace: .rightBraceToken(leadingTrivia: .newline))

        // Create attributes
        var attributes = AttributeListSyntax([])
        if let availability {
            let defaultMessage = "PromiseKit support is deprecated; use async function instead"
            let availabilityAttr = createAvailabilityAttributeWithMessage(
                originalFuncName: originalFuncName,
                availability: availability,
                defaultMessage: defaultMessage)
            attributes = attributes + [AttributeListSyntax.Element(availabilityAttr)]
        }

        return FunctionDeclSyntax(
            attributes: attributes,
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public)),
            ]),
            funcKeyword: .keyword(.func),
            name: .identifier(newFuncName),
            genericParameterClause: funcDecl.genericParameterClause,
            signature: asyncSignature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: body)
    }

    /// Parses the extension generation argument from the attribute
    private static func parseExtensionGenerationArgument(from node: AttributeSyntax)
        -> AwaitlessableExtensionGeneration
    {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return .enabled // Default value
        }

        for argument in arguments {
            if let label = argument.label,
               label.text == "extensionGeneration",
               let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
            {
                let name = memberAccess.declName.baseName
                switch name.text {
                case "disabled":
                    return .disabled
                case "enabled":
                    return .enabled
                default:
                    return .enabled
                }
            }
        }

        return .enabled // Default value
    }

    /// Parses prefix and availability arguments from the attribute
    private static func parseAttributeArguments(from node: AttributeSyntax) -> (String, AwaitlessAvailability?) {
        var prefix = ""
        var availability: AwaitlessAvailability? = .deprecated() // Default to deprecated

        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return (prefix, availability)
        }

        for argument in arguments {
            // Handle prefix parameter
            if argument.label?.text == "prefix",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self)
            {
                prefix = stringLiteral.segments.description
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            // Handle availability parameter - set default to deprecated when availability is explicitly used
            else if argument.label?.text != "prefix" && argument.label?.text != "extensionGeneration",
                    let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
            {
                if memberAccess.declName.baseName.text == "deprecated" {
                    availability = .deprecated()
                } else if memberAccess.declName.baseName.text == "unavailable" {
                    availability = .unavailable()
                }
            }
            // Handle availability with message
            else if argument.label?.text != "prefix" && argument.label?.text != "extensionGeneration",
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

        return (prefix, availability)
    }
}

// MARK: - AwaitfulableMacroDiagnostic

/// Diagnostics for errors related to the Awaitfulable macro
enum AwaitfulableMacroDiagnostic: String, DiagnosticMessage {
    case requiresProtocolOrClass = "@Awaitfulable can only be applied to protocols or classes"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessPromiseMacros", id: rawValue)
    }
}