import SpriteKit
import PuzzleCore
import UIKit

struct BoardLayout {
    static func tubes(size: CGSize, count: Int) -> [CGRect] {
        guard count > 0 else { return [] }
        let columns = min(3, count), rows = (count + columns - 1) / columns
        let cellWidth = size.width / CGFloat(columns), cellHeight = size.height / CGFloat(rows)
        let width = min(82, cellWidth - 24), height = min(218, cellHeight - 38)
        return (0..<count).map { index in
            let row = index / columns, column = index % columns
            let rowCount = min(columns, count - row * columns)
            let x = (size.width - CGFloat(rowCount) * cellWidth) / 2 + (CGFloat(column) + 0.5) * cellWidth
            let y = size.height - (CGFloat(row) + 0.5) * cellHeight
            return CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
        }
    }
}

extension PieceColor {
    var symbol: String { ["◆", "●", "✿", "✦"][rawValue] }
    var spokenName: String { ["coral diamond", "blue circle", "mint flower", "gold star"][rawValue] }
}

@MainActor
final class PuzzleScene: SKScene {
    var onSelect: ((Int) -> Void)?
    var reduceMotion = false
    private var state: PuzzleState?
    private var selected: Int?
    // Enabled only for a diagnostic workload; bounded samples, never uploaded.
    var collectsFrameMetrics = false
    private(set) var frameIntervals: [Double] = []
    private var lastFrameTime: Double?
    override func update(_ currentTime: TimeInterval) {
        guard collectsFrameMetrics else { lastFrameTime = nil; return }
        if let lastFrameTime, frameIntervals.count < 3_600 { frameIntervals.append(currentTime - lastFrameTime) }
        lastFrameTime = currentTime
    }
    private(set) var redrawCount = 0
    private var renderedSize: CGSize = .zero
    private var textures: [PieceColor: SKTexture] = [:]

    func render(state: PuzzleState, selected: Int?) {
        let previous = self.state
        self.state = state; self.selected = selected
        // Selection is a stroke update, not a new board. Preserve nodes and textures.
        if previous == state, renderedSize == size {
            updateSelection()
        } else { redraw() }
        if !reduceMotion, let previous {
            for index in state.containers.indices where Self.complete(state.containers[index]) && !Self.complete(previous.containers[index]) {
                childNode(withName: "tube-\(index)")?.run(.sequence([.scale(to: 1.06, duration: 0.14), .scale(to: 1, duration: 0.2)]))
            }
        }
    }

    static func complete(_ pieces: [PieceColor]) -> Bool { pieces.count == 4 && Set(pieces).count == 1 }
    override func didChangeSize(_ oldSize: CGSize) { redraw() }

    private func texture(for color: PieceColor) -> SKTexture {
        if let texture = textures[color] { return texture }
        let colors: [[UIColor]] = [
            [UIColor(red: 1, green: 0.63, blue: 0.52, alpha: 1), UIColor(red: 0.87, green: 0.30, blue: 0.32, alpha: 1)],
            [UIColor(red: 0.56, green: 0.79, blue: 1, alpha: 1), UIColor(red: 0.26, green: 0.46, blue: 0.85, alpha: 1)],
            [UIColor(red: 0.63, green: 0.93, blue: 0.74, alpha: 1), UIColor(red: 0.23, green: 0.68, blue: 0.53, alpha: 1)],
            [UIColor(red: 1, green: 0.87, blue: 0.48, alpha: 1), UIColor(red: 0.96, green: 0.62, blue: 0.23, alpha: 1)]]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 60)).image { context in
            let rect = CGRect(x: 4, y: 3, width: 88, height: 50)
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 3), blur: 4, color: UIColor.black.withAlphaComponent(0.28).cgColor)
            UIColor.white.setFill(); UIBezierPath(roundedRect: rect, cornerRadius: 15).fill()
            context.cgContext.setShadow(offset: .zero, blur: 0)
            context.cgContext.saveGState()
            UIBezierPath(roundedRect: rect, cornerRadius: 15).addClip()
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors[color.rawValue].map(\.cgColor) as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 56), options: [])
            }
            UIColor.white.withAlphaComponent(0.4).setStroke()
            let glint = UIBezierPath(); glint.move(to: CGPoint(x: 18, y: 12)); glint.addLine(to: CGPoint(x: 72, y: 12)); glint.lineWidth = 2; glint.stroke()
            context.cgContext.restoreGState()
        }
        let texture = SKTexture(image: image); textures[color] = texture; return texture
    }

    private func piece(_ color: PieceColor, size: CGSize) -> SKNode {
        let node = SKSpriteNode(texture: texture(for: color), size: size)
        let symbol = SKLabelNode(text: color.symbol)
        symbol.fontName = "AvenirNext-Bold"; symbol.fontSize = min(23, size.height * 0.58)
        symbol.fontColor = UIColor(red: 0.10, green: 0.19, blue: 0.23, alpha: 0.85)
        symbol.verticalAlignmentMode = .center; symbol.position.y = 2
        node.addChild(symbol); return node
    }

    private func position(slot: Int, rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.minY + 10 + (rect.height - 20) / 4 * (CGFloat(slot) + 0.5))
    }

    private func updateSelection() {
        guard let state else { return }
        for index in state.containers.indices {
            guard let tube = childNode(withName: "tube-\(index)")?.childNode(withName: "outline") as? SKShapeNode else { continue }
            tube.strokeColor = selected == index ? UIColor(red: 0.78, green: 1, blue: 0.76, alpha: 1) : .white.withAlphaComponent(Self.complete(state.containers[index]) ? 0.65 : 0.25)
            tube.lineWidth = selected == index ? 3 : 1.5; tube.glowWidth = selected == index ? 3 : 0
        }
    }
    private func redraw() {
        redrawCount += 1; renderedSize = size
        removeAllChildren()
        backgroundColor = UIColor(red: 0.08, green: 0.22, blue: 0.24, alpha: 1)
        for index in 0..<12 {
            let star = SKShapeNode(circleOfRadius: index % 3 == 0 ? 3 : 1.5)
            star.fillColor = .white.withAlphaComponent(0.12); star.strokeColor = .clear
            star.position = CGPoint(x: size.width * CGFloat((index * 37 + 11) % 100) / 100, y: size.height * CGFloat((index * 23 + 5) % 100) / 100)
            addChild(star)
        }
        guard let state else { return }
        let rects = BoardLayout.tubes(size: size, count: state.containers.count)
        for (index, pieces) in state.containers.enumerated() {
            let rect = rects[index]
            let group = SKNode(); group.name = "tube-\(index)"; group.position = CGPoint(x: rect.midX, y: rect.midY); addChild(group)
            let local = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
            let shadow = SKShapeNode(ellipseOf: CGSize(width: rect.width + 12, height: 16))
            shadow.position.y = -rect.height / 2 - 7; shadow.fillColor = .black.withAlphaComponent(0.18); shadow.strokeColor = .clear; group.addChild(shadow)
            let tube = SKShapeNode(rect: local, cornerRadius: 21)
            tube.name = "outline"
            tube.fillColor = .white.withAlphaComponent(0.055)
            tube.strokeColor = selected == index ? UIColor(red: 0.78, green: 1, blue: 0.76, alpha: 1) : .white.withAlphaComponent(Self.complete(pieces) ? 0.65 : 0.25)
            tube.lineWidth = selected == index ? 3 : 1.5; tube.glowWidth = selected == index ? 3 : 0
            group.addChild(tube)
            for (slot, color) in pieces.enumerated() {
                let node = piece(color, size: CGSize(width: rect.width - 10, height: (rect.height - 20) / 4))
                node.name = "piece-\(index)-\(slot)"
                let point = position(slot: slot, rect: rect)
                node.position = CGPoint(x: point.x - rect.midX, y: point.y - rect.midY)
                group.addChild(node)
            }
            let label = SKLabelNode(text: Self.complete(pieces) ? "✓" : "\(index + 1)")
            label.fontName = "AvenirNext-DemiBold"; label.fontSize = 13; label.fontColor = .white.withAlphaComponent(0.65)
            label.position = CGPoint(x: rect.midX, y: max(6, rect.minY - 23)); addChild(label)
        }
    }

    func animateMove(from source: Int, to destination: Int, previous: PuzzleState) {
        render(state: previous, selected: nil)
        renderedSize = .zero
        guard !reduceMotion, let color = previous.containers[source].last else { return }
        let rects = BoardLayout.tubes(size: size, count: previous.containers.count)
        childNode(withName: "tube-\(source)")?.childNode(withName: "piece-\(source)-\(previous.containers[source].count - 1)")?.removeFromParent()
        let start = position(slot: previous.containers[source].count - 1, rect: rects[source])
        let end = position(slot: previous.containers[destination].count, rect: rects[destination])
        let flying = piece(color, size: CGSize(width: rects[source].width - 10, height: (rects[source].height - 20) / 4))
        flying.position = start; flying.zPosition = 20; addChild(flying)
        let lift = max(rects[source].maxY, rects[destination].maxY) + 15
        let path = CGMutablePath(); path.move(to: start)
        path.addCurve(to: end, control1: CGPoint(x: start.x, y: lift), control2: CGPoint(x: end.x, y: lift))
        let action = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.42)
        action.timingMode = .easeInEaseOut; flying.run(action)
    }

    func invalid(at index: Int) {
        guard let node = childNode(withName: "tube-\(index)") else { return }
        if let tube = node.children.compactMap({ $0 as? SKShapeNode }).last { tube.strokeColor = .systemPink }
        guard !reduceMotion else { return }
        node.run(.sequence([.moveBy(x: -5, y: 0, duration: 0.05), .moveBy(x: 10, y: 0, duration: 0.08), .moveBy(x: -5, y: 0, duration: 0.05)]))
    }

    func celebrate() {
        guard !reduceMotion else { return }
        for index in 0..<32 {
            let spark = SKShapeNode(rectOf: CGSize(width: 5, height: 9), cornerRadius: 2)
            spark.fillColor = [.systemMint, .systemYellow, .systemPink, .white][index % 4]; spark.strokeColor = .clear
            spark.position = CGPoint(x: size.width / 2, y: size.height * 0.6); spark.zPosition = 30; addChild(spark)
            let x = CGFloat((index * 73) % 360) - 180, y = CGFloat(100 + (index * 31) % 160)
            spark.run(.sequence([.group([.moveBy(x: x, y: y, duration: 0.65), .rotate(byAngle: CGFloat(index), duration: 0.65), .fadeOut(withDuration: 0.9)]), .removeFromParent()]))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let state, let point = touches.first?.location(in: self) else { return }
        let rects = BoardLayout.tubes(size: size, count: state.containers.count)
        if let index = rects.firstIndex(where: { $0.insetBy(dx: -8, dy: -10).contains(point) }) { onSelect?(index) }
    }
}
