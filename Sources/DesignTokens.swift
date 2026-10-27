import SwiftUI

enum DS {
    enum ColorToken {
        static let primary = Color(hex: 0x0066cc)
        static let primaryFocus = Color(hex: 0x0071e3)
        static let ink = Color(hex: 0x1d1d1f)
        static let inkMuted80 = Color(hex: 0x333333)
        static let inkMuted48 = Color(hex: 0x7a7a7a)
        static let dividerSoft = Color(hex: 0xf0f0f0)
        static let hairline = Color(hex: 0xe0e0e0)
        static let canvas = Color(hex: 0xffffff)
        static let parchment = Color(hex: 0xf5f5f7)
        static let pearl = Color(hex: 0xfafafc)
        static let tile1 = Color(hex: 0x272729)
        static let tile2 = Color(hex: 0x2a2a2c)
        static let tile3 = Color(hex: 0x252527)
        static let surfaceBlack = Color(hex: 0x000000)
        static let onDark = Color(hex: 0xffffff)
        static let onPrimary = Color(hex: 0xffffff)
        static let bodyOnDark = Color(hex: 0xffffff)
        static let bodyMuted = Color(hex: 0xcccccc)
        static let primaryOnDark = Color(hex: 0x2997ff)
    }

    enum Typo {
        static func heroDisplay(_ t: String) -> Text { Text(t).font(.system(size: 56, weight: .semibold)).tracking(-0.28) }
        static func displayLG(_ t: String) -> Text { Text(t).font(.system(size: 40, weight: .semibold)).tracking(0) }
        static func displayMD(_ t: String) -> Text { Text(t).font(.system(size: 34, weight: .semibold)).tracking(-0.374) }
        static func lead(_ t: String) -> Text { Text(t).font(.system(size: 28, weight: .regular)).tracking(0.196) }
        static func tagline(_ t: String) -> Text { Text(t).font(.system(size: 21, weight: .semibold)).tracking(0.231) }
        static func bodyStrong(_ t: String) -> Text { Text(t).font(.system(size: 17, weight: .semibold)).tracking(-0.374) }
        static func body(_ t: String) -> Text { Text(t).font(.system(size: 17, weight: .regular)).tracking(-0.374) }
        static func caption(_ t: String) -> Text { Text(t).font(.system(size: 14, weight: .regular)).tracking(-0.224) }
        static func captionStrong(_ t: String) -> Text { Text(t).font(.system(size: 14, weight: .semibold)).tracking(-0.224) }
        static func buttonUtility(_ t: String) -> Text { Text(t).font(.system(size: 14, weight: .regular)).tracking(-0.224) }
        static func finePrint(_ t: String) -> Text { Text(t).font(.system(size: 12, weight: .regular)).tracking(-0.12) }
        static func navLink(_ t: String) -> Text { Text(t).font(.system(size: 12, weight: .regular)).tracking(-0.12) }
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 17
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let section: CGFloat = 80
    }

    enum Radius {
        static let xs: CGFloat = 5
        static let sm: CGFloat = 8
        static let md: CGFloat = 11
        static let lg: CGFloat = 18
        static let pill: CGFloat = 9999
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Liquid Crystal Glass
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 28, x: 0, y: 10)
    }
}

struct LiquidGlassDarkCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 28, x: 0, y: 10)
    }
}

// 색 있는 배경
struct LiquidBackground: View {
    var body: some View {
        ZStack {
            // 훨씬 옅은 파스텔
            LinearGradient(
                colors: [
                    Color(hex: 0xf4f6fb),
                    Color(hex: 0xf9f4fa),
                    Color(hex: 0xfdf6f4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // 아주 옅은 빛 번짐
            Circle()
                .fill(Color(hex: 0xc9d8f5).opacity(0.35))
                .frame(width: 600, height: 600)
                .blur(radius: 220)
                .offset(x: -300, y: -400)
            Circle()
                .fill(Color(hex: 0xf0c8d8).opacity(0.28))
                .frame(width: 550, height: 550)
                .blur(radius: 200)
                .offset(x: 350, y: 300)
        }
        .ignoresSafeArea()
    }
}
