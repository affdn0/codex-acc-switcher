import SwiftUI

struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(lineWidth: 1.7)
                .frame(width: 14, height: 9)
                .rotationEffect(.degrees(-10))
                .offset(x: -4, y: -3)
            RoundedRectangle(cornerRadius: 4)
                .stroke(lineWidth: 1.7)
                .frame(width: 14, height: 9)
                .rotationEffect(.degrees(10))
                .offset(x: 4, y: 3)
            Circle()
                .stroke(lineWidth: 1.8)
                .frame(width: 12, height: 12)
            Path { path in
                path.move(to: CGPoint(x: 8, y: 10))
                path.addLine(to: CGPoint(x: 12, y: 14))
                path.addLine(to: CGPoint(x: 8, y: 18))
                path.move(to: CGPoint(x: 14, y: 18))
                path.addLine(to: CGPoint(x: 18, y: 18))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 26, height: 26)
    }
}
