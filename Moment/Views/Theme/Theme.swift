//
//  Theme.swift
//  Moment
//
//  Design system for the app - calm, minimal, non-clinical
//

import SwiftUI

// MARK: - Colors

extension Color {
    // Primary palette - warm, organic tones
    static let momentCream = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let momentSand = Color(red: 0.94, green: 0.90, blue: 0.85)
    static let momentWarmGray = Color(red: 0.45, green: 0.42, blue: 0.40)
    static let momentCharcoal = Color(red: 0.20, green: 0.18, blue: 0.17)
    
    // Fertility colors - soft, nature-inspired
    static let momentGreen = Color(red: 0.36, green: 0.60, blue: 0.48)      // Peak - sage green
    static let momentTeal = Color(red: 0.45, green: 0.68, blue: 0.65)       // High - soft teal
    static let momentMist = Color(red: 0.78, green: 0.80, blue: 0.78)       // Low - morning mist
    
    // Partner view colors - muted versions
    static let momentPartnerGreen = Color(red: 0.42, green: 0.65, blue: 0.53)
    static let momentPartnerTeal = Color(red: 0.52, green: 0.72, blue: 0.70)
    static let momentPartnerMist = Color(red: 0.82, green: 0.84, blue: 0.82)
    
    // Accent colors
    static let momentRose = Color(red: 0.85, green: 0.65, blue: 0.62)       // Gentle accent
    static let momentAmber = Color(red: 0.90, green: 0.75, blue: 0.55)      // Warm highlight
    
    // Semantic colors
    static let momentBackground = momentCream
    static let momentCardBackground = Color.white
    static let momentText = momentCharcoal
    static let momentSecondaryText = momentWarmGray
    
    // Fertility level colors
    static func fertilityColor(for level: FertilityLevel) -> Color {
        switch level {
        case .peak: return .momentGreen
        case .high: return .momentTeal
        case .low: return .momentMist
        }
    }
    
    static func partnerFertilityColor(for level: FertilityLevel) -> Color {
        switch level {
        case .peak: return .momentPartnerGreen
        case .high: return .momentPartnerTeal
        case .low: return .momentPartnerMist
        }
    }
}

// MARK: - Typography

extension Font {
    // Display - for large headers
    static let momentDisplay = Font.system(size: 34, weight: .light, design: .serif)
    static let momentDisplaySmall = Font.system(size: 28, weight: .light, design: .serif)
    
    // Headlines
    static let momentHeadline = Font.system(size: 22, weight: .medium, design: .rounded)
    static let momentSubheadline = Font.system(size: 17, weight: .medium, design: .rounded)
    
    // Body
    static let momentBody = Font.system(size: 17, weight: .regular, design: .default)
    static let momentBodyMedium = Font.system(size: 17, weight: .medium, design: .default)
    static let momentBodySmall = Font.system(size: 15, weight: .regular, design: .default)
    
    // Caption
    static let momentCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let momentCaptionMedium = Font.system(size: 13, weight: .medium, design: .default)
    
    // Special
    static let momentCode = Font.system(size: 24, weight: .bold, design: .monospaced)
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
    static let pill: CGFloat = 100
}

// MARK: - Shadows

extension View {
    func momentShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    func momentShadowSubtle() -> some View {
        self.shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Button Styles

struct MomentPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.momentBodyMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isEnabled ? Color.momentCharcoal : Color.momentMist)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MomentSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.momentBodyMedium)
            .foregroundColor(.momentCharcoal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(Color.momentCharcoal.opacity(0.3), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MomentTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.momentBody)
            .foregroundColor(.momentWarmGray)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Card Style

struct MomentCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.lg
    
    init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.momentCardBackground)
            )
            .momentShadow()
    }
}

// MARK: - Text Field Style

struct MomentTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.momentBody)
            .foregroundStyle(Color.momentCharcoal)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.momentSand.opacity(0.5))
            )
    }
}

// MARK: - Animations

extension Animation {
    static let momentSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let momentEase = Animation.easeInOut(duration: 0.25)
}

// MARK: - View Extensions

extension View {
    func momentBackground() -> some View {
        self.background(Color.momentBackground.ignoresSafeArea())
    }
}
