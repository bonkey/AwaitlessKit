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

// MARK: - AccessLevel

/// Defines the access level for the generated property
public enum AccessLevel: String, ExpressibleByStringLiteral, Codable {
    case `private`
    case `internal`
    case `public`

    public init(stringLiteral value: String) {
        self = AccessLevel(rawValue: value) ?? .internal
    }
}

// MARK: - IsolatedSafeMacro

/// A macro that generates a thread-safe accessor for a nonisolated(unsafe) property.
/// This macro creates a property that wraps access to the original unsafe property
/// in a concurrent queue to provide thread safety.
public struct IsolatedSafeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext) throws
        -> [DeclSyntax]
    {
        // Validate that the declaration is a variable declaration
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: IsolatedSafeMacroDiagnostic.requiresProperty)
            context.diagnose(diagnostic)
            return []
        }

        // Check if the property is a 'var'
        guard varDecl.bindingSpecifier.text == "var" else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: IsolatedSafeMacroDiagnostic.requiresVar)
            context.diagnose(diagnostic)
            return []
        }

        // Check if the property has nonisolated(unsafe) modifier
        guard hasNonisolatedUnsafeModifier(varDecl.modifiers) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: IsolatedSafeMacroDiagnostic.requiresNonisolatedUnsafe)
            context.diagnose(diagnostic)
            return []
        }

        // Check if the property is private
        guard hasPrivateModifier(varDecl.modifiers) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: IsolatedSafeMacroDiagnostic.requiresPrivate)
            context.diagnose(diagnostic)
            return []
        }

        // Check binding and validate naming
        guard let binding = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self) else {
            return []
        }

        let propertyName = binding.identifier.text

        // Check if property starts with "_unsafe"
        guard propertyName.starts(with: "_unsafe"), propertyName.count > 7 else {
            let diagnostic = Diagnostic(
                node: Syntax(binding),
                message: IsolatedSafeMacroDiagnostic.requiresUnsafePrefix)
            context.diagnose(diagnostic)
            return []
        }

        // Extract type from the binding
        guard let initializer = varDecl.bindings.first?.typeAnnotation else {
            let diagnostic = Diagnostic(
                node: Syntax(binding),
                message: IsolatedSafeMacroDiagnostic.requiresTypeAnnotation)
            context.diagnose(diagnostic)
            return []
        }

        // Parse access level from macro arguments
        let accessLevel = parseAccessLevel(from: node)

        // Parse queue name from macro arguments, or generate a name based on property
        let queueName = parseQueueName(from: node, propertyName: propertyName, context: context)

        // Parse writable flag from macro arguments
        let isWritable = parseWritable(from: node)

        // Generate the safe property
        let safeProperty = generateSafeProperty(
            unsafePropertyName: propertyName,
            typeAnnotation: initializer,
            accessLevel: accessLevel,
            queueName: queueName,
            writable: isWritable)

        // Generate the queue if needed
        let queue = generateQueue(name: queueName, accessLevel: accessLevel)

        return [DeclSyntax(safeProperty), DeclSyntax(queue)]
    }

    /// Check if the variable has nonisolated(unsafe) modifier
    private static func hasNonisolatedUnsafeModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.text == "nonisolated",
               let detail = modifier.detail
            {
                // Check if the detail contains "unsafe"
                let detailText = detail.description
                if detailText.contains("unsafe") {
                    return true
                }
            }
        }
        return false
    }

    /// Check if the variable has private modifier
    private static func hasPrivateModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.text == "private" {
                return true
            }
        }
        return false
    }

    /// Parse access level from macro arguments
    private static func parseAccessLevel(from node: AttributeSyntax) -> AccessLevel {
        guard let labeledArguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return .internal
        }

        for argument in labeledArguments {
            if argument.label?.text == "accessLevel",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                let value = segment.content.text
                return AccessLevel(rawValue: value) ?? .internal
            }
        }

        return .internal
    }

    /// Parse writable flag from macro arguments
    private static func parseWritable(from node: AttributeSyntax) -> Bool {
        guard let labeledArguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return false
        }

        for argument in labeledArguments {
            if argument.label?.text == "writable",
               let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self)
            {
                return boolLiteral.literal.text == "true"
            }
        }

        return false
    }

    /// Parse queue name from macro arguments or generate one based on property name
    private static func parseQueueName(
        from node: AttributeSyntax,
        propertyName: String,
        context: some MacroExpansionContext)
        -> String
    {
        guard let labeledArguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            // Compute the property name without "_unsafe" prefix
            let baseName = String(propertyName.dropFirst(7))
            let safePropertyName = baseName.prefix(1).lowercased() + baseName.dropFirst()
            return "accessQueue\(safePropertyName.prefix(1).uppercased() + safePropertyName.dropFirst())"
        }

        for argument in labeledArguments {
            if argument.label?.text == "queueName",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
            {
                return segment.content.text
            }
        }

        // Compute the property name without "_unsafe" prefix
        let baseName = String(propertyName.dropFirst(7))
        let safePropertyName = baseName.prefix(1).lowercased() + baseName.dropFirst()
        return "accessQueue\(safePropertyName.prefix(1).uppercased() + safePropertyName.dropFirst())"
    }

    /// Generate the safe property with getters and setters
    private static func generateSafeProperty(
        unsafePropertyName: String,
        typeAnnotation: TypeAnnotationSyntax,
        accessLevel: AccessLevel,
        queueName: String,
        writable: Bool = false)
        -> VariableDeclSyntax
    {
        // Compute the new property name by removing "_unsafe" prefix and lowercasing first letter
        let baseName = String(unsafePropertyName.dropFirst(7))
        let safePropertyName = baseName.prefix(1).lowercased() + baseName.dropFirst()

        // Create accessors
        var accessors = AccessorDeclListSyntax {
            // Getter
            AccessorDeclSyntax(
                accessorSpecifier: .keyword(.get),
                body: CodeBlockSyntax {
                    ExprSyntax("""
                    \(raw: queueName).sync { self.\(raw: unsafePropertyName) }
                    """)
                })
        }

        // Add setter if writable
        if writable {
            accessors.append(
                AccessorDeclSyntax(
                    accessorSpecifier: .keyword(.set),
                    body: CodeBlockSyntax {
                        ExprSyntax("""
                        \(raw: queueName).async(flags: .barrier) { self.\(raw: unsafePropertyName) = newValue }
                        """)
                    }))
        }

        // Create the computed property with get and set accessors
        return VariableDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .identifier(accessLevel.rawValue))
            },
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(safePropertyName)),
                    typeAnnotation: typeAnnotation,
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .accessors(accessors)))
            })
    }

    /// Generate the queue property
    private static func generateQueue(name: String, accessLevel: AccessLevel) -> VariableDeclSyntax {
        VariableDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .identifier("private"))
            },
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                    initializer: InitializerClauseSyntax(
                        value: ExprSyntax("""
                        DispatchQueue(label: "\(raw: name)", attributes: .concurrent)
                        """)))
            })
    }
}

// MARK: - IsolatedSafeMacroDiagnostic

/// Diagnostics for errors related to the IsolatedSafe macro
enum IsolatedSafeMacroDiagnostic: String, DiagnosticMessage {
    case requiresProperty = "@IsolatedSafe can only be applied to properties"
    case requiresVar = "@IsolatedSafe can only be applied to 'var' properties"
    case requiresNonisolatedUnsafe = "@IsolatedSafe requires the property to be marked as 'nonisolated(unsafe)'"
    case requiresPrivate = "@IsolatedSafe requires the property to be 'private'"
    case requiresUnsafePrefix = "@IsolatedSafe requires the property name to start with '_unsafe'"
    case requiresTypeAnnotation = "@IsolatedSafe requires the property to have an explicit type annotation"

    var severity: DiagnosticSeverity { .error }
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "IsolatedSafeMacros", id: rawValue)
    }
}
