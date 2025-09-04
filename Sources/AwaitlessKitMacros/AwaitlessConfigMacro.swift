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

/// A macro that generates type-scoped configuration for AwaitlessKit macros.
/// This macro adds a static __awaitlessConfig property to types that can be
/// checked by other AwaitlessKit macros to apply defaults.
public struct AwaitlessConfigMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        // Ensure this is applied to a type declaration
        guard declaration.is(ClassDeclSyntax.self) || 
              declaration.is(StructDeclSyntax.self) || 
              declaration.is(ActorDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: Syntax(declaration),
                message: AwaitlessConfigMacroDiagnostic.requiresType)
            context.diagnose(diagnostic)
            return []
        }
        
        // Parse configuration parameters from the attribute
        let configData = try parseConfigurationData(from: node, context: context)
        
        // Generate the __awaitlessConfig static property
        let configProperty = try generateConfigProperty(configData: configData)
        
        return [DeclSyntax(configProperty)]
    }
    
    /// Parses configuration data from the @AwaitlessConfig attribute arguments
    private static func parseConfigurationData(
        from node: AttributeSyntax,
        context: some MacroExpansionContext
    ) throws -> AwaitlessConfigData {
        var prefix: String? = nil
        var availability: AwaitlessAvailability? = nil
        var delivery: AwaitlessDelivery? = nil
        var strategy: AwaitlessSynchronizationStrategy? = nil
        
        guard case let .argumentList(arguments) = node.arguments else {
            // No arguments provided, return empty config
            return AwaitlessConfigData()
        }
        
        for argument in arguments {
            guard let label = argument.label?.text else { continue }
            
            switch label {
            case "prefix":
                if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                    prefix = stringLiteral.segments.description
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
                
            case "availability":
                availability = try parseAvailability(from: argument.expression, context: context)
                
            case "delivery":
                delivery = try parseDelivery(from: argument.expression, context: context)
                
            case "strategy":
                strategy = try parseStrategy(from: argument.expression, context: context)
                
            default:
                // Unknown parameter, could warn but for now we ignore
                break
            }
        }
        
        return AwaitlessConfigData(
            prefix: prefix,
            availability: availability,
            delivery: delivery,
            strategy: strategy
        )
    }
    
    /// Parses AwaitlessAvailability from an expression
    private static func parseAvailability(
        from expression: ExprSyntax,
        context: some MacroExpansionContext
    ) throws -> AwaitlessAvailability? {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            switch memberAccess.declName.baseName.text {
            case "deprecated":
                return .deprecated()
            case "unavailable":
                return .unavailable()
            default:
                return nil
            }
        } else if let functionCall = expression.as(FunctionCallExprSyntax.self),
                  let calledExpr = functionCall.calledExpression.as(MemberAccessExprSyntax.self) {
            let methodName = calledExpr.declName.baseName.text
            let message = functionCall.arguments.first?.expression
                .as(StringLiteralExprSyntax.self)?
                .segments.description
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            
            switch methodName {
            case "deprecated":
                return .deprecated(message)
            case "unavailable":
                return .unavailable(message)
            default:
                return nil
            }
        }
        
        return nil
    }
    
    /// Parses AwaitlessDelivery from an expression
    private static func parseDelivery(
        from expression: ExprSyntax,
        context: some MacroExpansionContext
    ) throws -> AwaitlessDelivery? {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            switch memberAccess.declName.baseName.text {
            case "current":
                return .current
            case "main":
                return .main
            default:
                return nil
            }
        }
        return nil
    }
    
    /// Parses AwaitlessSynchronizationStrategy from an expression
    private static func parseStrategy(
        from expression: ExprSyntax,
        context: some MacroExpansionContext
    ) throws -> AwaitlessSynchronizationStrategy? {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            switch memberAccess.declName.baseName.text {
            case "concurrent":
                return .concurrent
            case "serial":
                return .serial
            default:
                return nil
            }
        }
        return nil
    }
    
    /// Generates the __awaitlessConfig static property declaration
    private static func generateConfigProperty(
        configData: AwaitlessConfigData
    ) throws -> VariableDeclSyntax {
        
        // Create the initializer call for AwaitlessConfigData
        var arguments: [LabeledExprSyntax] = []
        
        if let prefix = configData.prefix {
            arguments.append(LabeledExprSyntax(
                label: .identifier("prefix"),
                colon: .colonToken(trailingTrivia: .space),
                expression: StringLiteralExprSyntax(content: prefix)
            ))
        }
        
        if let availability = configData.availability {
            arguments.append(LabeledExprSyntax(
                label: .identifier("availability"),
                colon: .colonToken(trailingTrivia: .space),
                expression: createAvailabilityExpression(availability)
            ))
        }
        
        if let delivery = configData.delivery {
            arguments.append(LabeledExprSyntax(
                label: .identifier("delivery"),
                colon: .colonToken(trailingTrivia: .space),
                expression: createDeliveryExpression(delivery)
            ))
        }
        
        if let strategy = configData.strategy {
            arguments.append(LabeledExprSyntax(
                label: .identifier("strategy"),
                colon: .colonToken(trailingTrivia: .space),
                expression: createStrategyExpression(strategy)
            ))
        }
        
        // Add trailing commas to all arguments except the last
        for i in 0..<arguments.count {
            if i < arguments.count - 1 {
                arguments[i] = arguments[i].with(\.trailingComma, .commaToken())
            }
        }
        
        let initCall = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessConfigData")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(arguments),
            rightParen: .rightParenToken()
        )
        
        // Create the static property declaration
        return VariableDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .keyword(.static))
            },
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("__awaitlessConfig")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: IdentifierTypeSyntax(name: .identifier("AwaitlessConfigData"))
                    ),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                        value: ExprSyntax(initCall)
                    )
                )
            }
        )
    }
    
    /// Creates an expression for AwaitlessAvailability
    private static func createAvailabilityExpression(_ availability: AwaitlessAvailability) -> ExprSyntax {
        switch availability {
        case .deprecated(let message):
            if let message = message {
                return ExprSyntax(FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessAvailability")),
                        period: .periodToken(),
                        name: .identifier("deprecated")
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(expression: StringLiteralExprSyntax(content: message))
                    },
                    rightParen: .rightParenToken()
                ))
            } else {
                return ExprSyntax(MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessAvailability")),
                    period: .periodToken(),
                    name: .identifier("deprecated")
                ))
            }
        case .unavailable(let message):
            if let message = message {
                return ExprSyntax(FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessAvailability")),
                        period: .periodToken(),
                        name: .identifier("unavailable")
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax {
                        LabeledExprSyntax(expression: StringLiteralExprSyntax(content: message))
                    },
                    rightParen: .rightParenToken()
                ))
            } else {
                return ExprSyntax(MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessAvailability")),
                    period: .periodToken(),
                    name: .identifier("unavailable")
                ))
            }
        }
    }
    
    /// Creates an expression for AwaitlessDelivery
    private static func createDeliveryExpression(_ delivery: AwaitlessDelivery) -> ExprSyntax {
        let memberName = switch delivery {
        case .current: "current"
        case .main: "main"
        }
        
        return ExprSyntax(MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessDelivery")),
            period: .periodToken(),
            name: .identifier(memberName)
        ))
    }
    
    /// Creates an expression for AwaitlessSynchronizationStrategy
    private static func createStrategyExpression(_ strategy: AwaitlessSynchronizationStrategy) -> ExprSyntax {
        let memberName = switch strategy {
        case .concurrent: "concurrent"
        case .serial: "serial"
        }
        
        return ExprSyntax(MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("AwaitlessSynchronizationStrategy")),
            period: .periodToken(),
            name: .identifier(memberName)
        ))
    }
}

// MARK: - AwaitlessConfigMacroDiagnostic

/// Diagnostics for errors related to the AwaitlessConfig macro
enum AwaitlessConfigMacroDiagnostic: String, DiagnosticMessage {
    case requiresType = "@AwaitlessConfig can only be applied to classes, structs, or actors"
    
    var severity: DiagnosticSeverity {
        .error
    }
    
    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "AwaitlessMacros", id: rawValue)
    }
}