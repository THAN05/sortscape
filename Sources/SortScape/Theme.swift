import SwiftUI

enum ScapeTheme {
    static let ink = Color(red: 0.10, green: 0.19, blue: 0.23)
    static let teal = Color(red: 0.13, green: 0.40, blue: 0.38)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.91)
    static let coral = Color(red: 0.91, green: 0.40, blue: 0.33)
}

/// Original code-drawn landscape; crisp at every display size without downloaded art.
struct WorldArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [Color(red: 0.76, green: 0.89, blue: 0.83), ScapeTheme.cream], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1, green: 0.85, blue: 0.57)).frame(width: 88, height: 88).position(x: size.width * 0.77, y: size.height * 0.22)
                ForEach(0..<3) { index in
                    Ellipse().fill([Color(red: 0.55, green: 0.74, blue: 0.66), Color(red: 0.36, green: 0.61, blue: 0.53), ScapeTheme.teal][index])
                        .frame(width: size.width * 1.45, height: size.height * 0.6)
                        .rotationEffect(.degrees(Double(index % 2 == 0 ? -12 : 14)))
                        .position(x: size.width * (index % 2 == 0 ? 0.3 : 0.8), y: size.height * (0.85 + Double(index) * 0.12))
                }
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<3) { index in
                        VStack(spacing: 5) {
                            ForEach(0..<(index + 2), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 10).fill([ScapeTheme.coral, Color(red: 0.98, green: 0.76, blue: 0.37), Color(red: 0.34, green: 0.70, blue: 0.64)][index].gradient)
                                    .overlay(Text(["◆", "✦", "✿"][index]).foregroundStyle(.white).font(.title3.bold()))
                                    .frame(width: 39, height: 29)
                            }
                        }.padding(7).background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.7), lineWidth: 2))
                    }
                }.scaleEffect(min(1, size.height / 230)).shadow(color: ScapeTheme.ink.opacity(0.15), radius: 12, y: 8).position(x: size.width * 0.45, y: size.height * 0.60)
            }.clipped()
        }.dynamicTypeSize(.medium).accessibilityHidden(true)
    }
}

struct ScapeButtonStyle: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(secondary ? ScapeTheme.ink : .white)
            .background(secondary ? Color.white.opacity(0.85) : ScapeTheme.teal, in: RoundedRectangle(cornerRadius: 20))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct StarRating: View {
    let stars: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...3, id: \.self) { index in
                Image(systemName: index <= stars ? "star.fill" : "star")
                    .foregroundStyle(index <= stars ? Color(red: 0.66, green: 0.43, blue: 0.08) : ScapeTheme.teal.opacity(0.45))
            }
        }.font(.caption).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(stars) of 3 stars")
    }
}
