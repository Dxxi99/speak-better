import SwiftUI

// MARK: - Primary (파란 pill)
struct ApplePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InternalPrimaryButton(configuration: configuration)
    }
}

private struct InternalPrimaryButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 22)
            .background(
                ZStack {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: 0x2a85e8), Color(hex: 0x0066cc)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                    // 호버 시 흰색 오버레이
                    Capsule().fill(Color.white.opacity(hovering ? 0.12 : 0))
                    // 누를 때 어두운 오버레이
                    Capsule().fill(Color.black.opacity(configuration.isPressed ? 0.15 : 0))
                }
            )
            .shadow(
                color: Color(hex: 0x0066cc).opacity(configuration.isPressed ? 0.5 : 0.35),
                radius: configuration.isPressed ? 6 : 12,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (hovering ? 1.02 : 1.0))
            .brightness(hovering && !configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
    }
}

// MARK: - Secondary (흰 pill)
struct AppleSecondaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InternalSecondaryButton(configuration: configuration)
    }
}

private struct InternalSecondaryButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(DS.ColorToken.ink)
            .padding(.vertical, 10)
            .padding(.horizontal, 22)
            .background(
                ZStack {
                    Capsule().fill(DS.ColorToken.canvas)
                    Capsule().strokeBorder(
                        configuration.isPressed ? DS.ColorToken.ink.opacity(0.25) : DS.ColorToken.ink.opacity(0.12),
                        lineWidth: 1
                    )
                    Capsule().fill(Color.black.opacity(hovering ? 0.04 : 0))
                }
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.02 : 0.06),
                radius: configuration.isPressed ? 2 : 6,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (hovering ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
    }
}

// MARK: - Utility (검정 작은 버튼)
struct AppleUtilityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InternalUtilityButton(configuration: configuration)
    }
}

private struct InternalUtilityButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 14, weight: .medium)).tracking(-0.224)
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm).fill(DS.ColorToken.ink)
                    RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.white.opacity(hovering ? 0.12 : 0))
                    RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.black.opacity(configuration.isPressed ? 0.3 : 0))
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (hovering ? 1.03 : 1.0))
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.15), radius: configuration.isPressed ? 2 : 6, x: 0, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
    }
}

// MARK: - Pearl 캡슐
struct ApplePearlCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        InternalPearlButton(configuration: configuration)
    }
}

private struct InternalPearlButton: View {
    let configuration: ButtonStyle.Configuration
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(DS.ColorToken.inkMuted80)
            .padding(.vertical, 7)
            .padding(.horizontal, 13)
            .background(
                ZStack {
                    Capsule().fill(DS.ColorToken.pearl)
                    Capsule().strokeBorder(DS.ColorToken.dividerSoft, lineWidth: 2)
                    Capsule().fill(Color.black.opacity(hovering ? 0.05 : 0))
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : (hovering ? 1.03 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
    }
}
