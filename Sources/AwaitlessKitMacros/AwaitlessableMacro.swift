//
// Copyright (c) 2025 Daniel Bauke
//

public import SwiftSyntax
public import SwiftSyntaxMacros
import SwiftDiagnostics

/// Macro that generates sync method signatures for protocols with async methods
public struct AwaitlessableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
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
    
    /// Creates a sync function signature from an async function declaration
    private static func createSyncFunctionSignature(
        from funcDecl: FunctionDeclSyntax
    ) -> FunctionDeclSyntax {
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