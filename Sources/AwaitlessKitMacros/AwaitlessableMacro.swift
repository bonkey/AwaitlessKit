//
// Copyright (c) 2025 Daniel Bauke
//

public import SwiftSyntax
public import SwiftSyntaxMacros
import AwaitlessCore
import SwiftDiagnostics

// MARK: - AwaitlessableMacro

/// Macro that generates sync method signatures for protocols with async methods
public struct AwaitlessableMacro: MemberMacro, ExtensionMacro {
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
                message: AwaitlessableMacroDiagnostic.requiresProtocol)
            context.diagnose(diagnostic)
            return []
        }

        // For protocols, we create sync versions of async methods as member declarations
        var memberDeclarations: [DeclSyntax] = []

        // Process all members to find async functions
        for member in protocolDecl.memberBlock.members {
            // If this is an async function, create its sync version as a member declaration
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                // Check if the function is async
                let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil

                if isAsync {
                    // Create a sync version of the async function
                    let syncFunction = createSyncFunctionSignature(from: functionDecl)
                    memberDeclarations.append(DeclSyntax(syncFunction))
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
        // Parse the extension generation configuration
        let extensionGeneration = parseExtensionGenerationArgument(from: node)

        // Only generate extensions if enabled
        guard extensionGeneration == .enabled else {
            return []
        }

        // Handle protocol declarations
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitlessableMacroDiagnostic.requiresProtocol)
            context.diagnose(diagnostic)
            return []
        }

        // Generate extension with default implementations
        var extensionMembers: [MemberBlockItemSyntax] = []

        // Process all members to find async functions
        for member in protocolDecl.memberBlock.members {
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                // Check if the function is async
                let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil

                if isAsync {
                    // Create a sync version with default implementation using Awaitless.run
                    let syncFunction = createSyncFunctionWithDefaultImplementation(from: functionDecl)
                    extensionMembers.append(MemberBlockItemSyntax(decl: DeclSyntax(syncFunction)))
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

    /// Creates a sync function signature from an async function declaration
    private static func createSyncFunctionSignature(
        from funcDecl: FunctionDeclSyntax)
        -> FunctionDeclSyntax
    {
        // Remove async specifier but keep throws if present
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false

        let newEffectSpecifiers: FunctionEffectSpecifiersSyntax? =
            if isThrowing {
                FunctionEffectSpecifiersSyntax(
                    asyncSpecifier: nil,
                    throwsClause: ThrowsClauseSyntax(
                        throwsSpecifier: .keyword(.throws)))
            } else {
                nil
            }

        let newSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: newEffectSpecifiers,
            returnClause: funcDecl.signature.returnClause)

        return FunctionDeclSyntax(
            attributes: AttributeListSyntax([]),
            modifiers: funcDecl.modifiers,
            funcKeyword: .keyword(.func),
            name: funcDecl.name,
            genericParameterClause: funcDecl.genericParameterClause,
            signature: newSignature,
            genericWhereClause: funcDecl.genericWhereClause,
            body: nil)
    }

    /// Creates a sync function with default implementation using Awaitless.run
    private static func createSyncFunctionWithDefaultImplementation(
        from funcDecl: FunctionDeclSyntax)
        -> FunctionDeclSyntax
    {
        // Remove async specifier but keep throws if present
        let isThrowing = funcDecl.signature.effectSpecifiers?.description.contains("throws") ?? false

        let newEffectSpecifiers: FunctionEffectSpecifiersSyntax? =
            if isThrowing {
                FunctionEffectSpecifiersSyntax(
                    asyncSpecifier: nil,
                    throwsClause: ThrowsClauseSyntax(
                        throwsSpecifier: .keyword(.throws)))
            } else {
                nil
            }

        let newSignature = FunctionSignatureSyntax(
            parameterClause: funcDecl.signature.parameterClause,
            effectSpecifiers: newEffectSpecifiers,
            returnClause: funcDecl.signature.returnClause)

        // Generate parameter call for the async call
        let parameters = funcDecl.signature.parameterClause.parameters
        let argumentList = createArgumentList(from: parameters)

        // Create the function call to the original async function
        let asyncCallExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self")),
                period: .periodToken(),
                name: funcDecl.name
            ),
            leftParen: .leftParenToken(),
            arguments: argumentList,
            rightParen: .rightParenToken()
        )

        // Add await to the async call
        let awaitExpression = AwaitExprSyntax(expression: ExprSyntax(asyncCallExpr))

        // If the original function throws, add try to the call
        let innerCallExpr: ExprSyntax = isThrowing
            ? ExprSyntax(TryExprSyntax(expression: awaitExpression))
            : ExprSyntax(awaitExpression)

        // Create the closure for Noasync.run with proper formatting
        let innerClosure = ClosureExprSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(innerCallExpr))
            },
            rightBrace: .rightBraceToken(leadingTrivia: .newline)
        )

        // Create the Noasync.run call with trailing closure syntax
        let taskNoasyncCall = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Noasync")),
                period: .periodToken(),
                name: .identifier("run")
            ),
            leftParen: nil,
            arguments: LabeledExprListSyntax([]),
            rightParen: nil,
            trailingClosure: innerClosure
        )

        // Wrap with try if needed
        let finalCall: ExprSyntax = isThrowing
            ? ExprSyntax(TryExprSyntax(expression: ExprSyntax(taskNoasyncCall)))
            : ExprSyntax(taskNoasyncCall)

        // Wrap with return if function has return value
        let hasReturnValue = funcDecl.signature.returnClause != nil
        let finalExpression: CodeBlockItemSyntax.Item = hasReturnValue
            ? .stmt(StmtSyntax(ReturnStmtSyntax(expression: finalCall)))
            : .expr(finalCall)

        let body = CodeBlockSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: finalExpression)
            ]),
            rightBrace: .rightBraceToken(leadingTrivia: .newline)
        )

        return FunctionDeclSyntax(
            attributes: AttributeListSyntax([]),
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public)),
            ]),
            funcKeyword: .keyword(.func),
            name: funcDecl.name,
            genericParameterClause: funcDecl.genericParameterClause,
            signature: newSignature,
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
}

// MARK: - AwaitlessableMacroDiagnostic

/// Diagnostics for errors related to the Awaitlessable macro
enum AwaitlessableMacroDiagnostic: String, DiagnosticMessage {
    case requiresProtocol = "@Awaitlessable can only be applied to protocols"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}
