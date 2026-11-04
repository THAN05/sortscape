import SpriteKit
import UIKit
import PuzzleCore

enum IslandRewardArt {
    static func name(for id: DecorationID) -> String? {
        switch id {
        case .cottage: "IslandCottage"
        case .lighthouse: "IslandLighthouse"
        case .pathways: "IslandPathways"
        case .trees: "IslandTrees"
        case .flowerGarden: "IslandFlowerGarden"
        case .bridge: "IslandBridge"
        case .picnic: "IslandPicnic"
        case .fountain: "IslandFountain"
        case .windmill: "IslandWindmill"
        case .dock: "IslandDock"
        }
    }
}

struct IslandLayout {
    static func point(column: Int, row: Int) -> CGPoint {
        CGPoint(x: CGFloat(column - row) * 30, y: CGFloat(column + row) * 15)
    }
}

@MainActor
final class IslandScene: SKScene {
    var onSelect: ((DecorationID) -> Void)?
    var reduceMotion = false
    private var progress = PlayerProgress()
    private var initialized = false
    private var renderKey = ""
    private var selection: DecorationID?
    private var sites: [DecorationID: CGPoint] = [:]
    private let world = SKNode()

    func update(progress: PlayerProgress, selected: DecorationID? = nil) {
        let key = RestorationItem.all.map { "\($0.id.rawValue):\(progress.island.restored.contains($0.id)):\(progress.restorationStatus($0))" }.joined(separator: "|") + "\(progress.purchases.premiumThemeSelected && progress.purchases.ownsTheme)|\(selected?.rawValue ?? "")|\(reduceMotion)|\(size)"
        guard key != renderKey else { return }
        renderKey = key; selection = selected
        let added = initialized ? progress.island.restored.subtracting(self.progress.island.restored) : []
        self.progress = progress; initialized = true
        redraw(selected: selected)
        guard !reduceMotion else { return }
        for id in added {
            if let node = world.childNode(withName: id.rawValue) {
                node.setScale(0.05); node.alpha = 0
                let grow = SKAction.scale(to: 1.10, duration: 0.3); grow.timingMode = .easeOut
                node.run(.sequence([.group([grow, .fadeIn(withDuration: 0.25)]), .scale(to: 1, duration: 0.18)]))
                for index in 0..<8 {
                    let spark = shape(.ellipse, rect: CGRect(x: -2, y: -2, width: 4, height: 4), color: .systemYellow)
                    spark.position = node.position; spark.zPosition = 1000; world.addChild(spark)
                    let angle = CGFloat(index) * .pi / 4
                    spark.run(.sequence([.group([.moveBy(x: cos(angle) * 45, y: sin(angle) * 30 + 30, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
                }
            }
        }
    }
    override func didChangeSize(_ oldSize: CGSize) { if initialized { redraw(selected: selection) } }
    private enum Shape { case rectangle, ellipse }
    private func shape(_ kind: Shape = .rectangle, rect: CGRect, color: SKColor, radius: CGFloat = 3) -> SKShapeNode {
        let node = kind == .ellipse ? SKShapeNode(ellipseIn: rect) : SKShapeNode(rect: rect, cornerRadius: radius)
        node.fillColor = color; node.strokeColor = .clear; return node
    }
    private func polygon(_ points: [CGPoint], color: SKColor) -> SKShapeNode {
        let path = CGMutablePath(); if let first = points.first { path.move(to: first) }
        for point in points.dropFirst() { path.addLine(to: point) }; path.closeSubpath()
        let node = SKShapeNode(path: path); node.fillColor = color; node.strokeColor = color; node.lineWidth = 0.5; return node
    }
    private func line(_ points: [CGPoint], color: SKColor, width: CGFloat = 2) -> SKShapeNode {
        let path = CGMutablePath(); if let first = points.first { path.move(to: first) }
        for point in points.dropFirst() { path.addLine(to: point) }
        let node = SKShapeNode(path: path); node.strokeColor = color; node.lineWidth = width; node.lineCap = .round; return node
    }
    private let sea = SKColor(red: 0.66, green: 0.85, blue: 0.84, alpha: 1)
    private let grass = SKColor(red: 0.45, green: 0.68, blue: 0.48, alpha: 1)
    private let cream = SKColor(red: 0.98, green: 0.91, blue: 0.73, alpha: 1)
    private let wood = SKColor(red: 0.52, green: 0.34, blue: 0.22, alpha: 1)
    private let coral = SKColor(red: 0.90, green: 0.43, blue: 0.34, alpha: 1)
    private let teal = SKColor(red: 0.14, green: 0.39, blue: 0.36, alpha: 1)

    private func redraw(selected: DecorationID?) {
        removeAllChildren(); world.removeAllChildren(); sites.removeAll()
        let moonlit = progress.purchases.premiumThemeSelected && progress.purchases.ownsTheme
        backgroundColor = moonlit ? SKColor(red: 0.16, green: 0.24, blue: 0.39, alpha: 1) : sea
        if moonlit {
            let moon = shape(.ellipse, rect: CGRect(x: size.width - 70, y: size.height - 65, width: 32, height: 32), color: cream)
            addChild(moon)
            for index in 0..<12 {
                let star = shape(.ellipse, rect: CGRect(x: CGFloat(index * 79 % max(1, Int(size.width))), y: size.height * 0.73 + CGFloat(index % 3) * 22, width: 3, height: 3), color: .white)
                addChild(star)
            }
        }
        world.position = CGPoint(x: size.width / 2, y: size.height * 0.46)
        world.setScale(min(size.width / 410, size.height / 320))
        addChild(world)
        let shadow = shape(.ellipse, rect: CGRect(x: -180, y: -113, width: 360, height: 130), color: teal.withAlphaComponent(0.12))
        shadow.zPosition = -200; world.addChild(shadow)
        // Rounded banks follow the existing plot grid without exposing a checkerboard.
        let shore = CGMutablePath()
        shore.move(to: CGPoint(x: -146, y: -35))
        shore.addCurve(to: CGPoint(x: -139, y: 31), control1: CGPoint(x: -197, y: -12), control2: CGPoint(x: -188, y: 10))
        shore.addCurve(to: CGPoint(x: 35, y: 100), control1: CGPoint(x: -91, y: 64), control2: CGPoint(x: -15, y: 111))
        shore.addCurve(to: CGPoint(x: 167, y: 28), control1: CGPoint(x: 93, y: 90), control2: CGPoint(x: 126, y: 50))
        shore.addCurve(to: CGPoint(x: 120, y: -44), control1: CGPoint(x: 206, y: 5), control2: CGPoint(x: 173, y: -22))
        shore.addCurve(to: CGPoint(x: -4, y: -98), control1: CGPoint(x: 67, y: -66), control2: CGPoint(x: 33, y: -102))
        shore.addCurve(to: CGPoint(x: -146, y: -35), control1: CGPoint(x: -58, y: -95), control2: CGPoint(x: -104, y: -57))
        shore.closeSubpath()
        func bank(_ color: SKColor, scale: CGFloat, height: CGFloat, depth: CGFloat) {
            let layer = SKShapeNode(path: shore)
            layer.fillColor = color; layer.strokeColor = .clear
            layer.setScale(scale); layer.position.y = height; layer.zPosition = depth
            world.addChild(layer)
        }
        bank(teal.withAlphaComponent(0.15), scale: 1.045, height: -10, depth: -104)
        bank(SKColor(red: 0.65, green: 0.49, blue: 0.33, alpha: 1), scale: 1, height: -10, depth: -103)
        bank(cream, scale: 1, height: 0, depth: -102)
        bank(SKColor(red: 0.36, green: 0.58, blue: 0.39, alpha: 1), scale: 0.91, height: 1, depth: -101)
        bank(grass, scale: 0.875, height: 4, depth: -100)
        for index in 0..<34 {
            let x = CGFloat(index * 67 % 246) - 123
            let y = CGFloat(index * 37 % 118) - 59
            guard abs(x) / 155 + abs(y) / 78 < 0.96 else { continue }
            let fleck = shape(.ellipse, rect: CGRect(x: x, y: y, width: 4 + CGFloat(index % 4), height: 2),
                              color: index.isMultiple(of: 3) ? cream.withAlphaComponent(0.44) : teal.withAlphaComponent(0.19))
            fleck.zPosition = -95; world.addChild(fleck)
        }
        for index in 0..<7 {
            let x = CGFloat(index * 61 % 340) - 170, y = CGFloat(index % 2 == 0 ? -110 : 96)
            let wave = line([CGPoint(x: x,y: y),CGPoint(x: x + 12,y: y + 2),CGPoint(x: x + 24,y: y)], color: .white.withAlphaComponent(0.45))
            wave.zPosition = -120; world.addChild(wave)
            if !reduceMotion { wave.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 1.8), .fadeAlpha(to: 1, duration: 1.8)]))) }
        }
        for item in RestorationItem.all {
            let point = IslandLayout.point(column: item.column, row: item.row)
            sites[item.id] = point
            let group = SKNode(); group.name = item.id.rawValue; group.position = point; group.zPosition = -point.y
            world.addChild(group)
            if progress.island.restored.contains(item.id) { draw(item.id, into: group) }
            else {
                let ready = progress.restorationStatus(item) == .available
                let marker = shape(.ellipse, rect: CGRect(x: -13,y: -7,width: 26,height: 14), color: ready ? cream : .white.withAlphaComponent(0.45))
                marker.strokeColor = selected == item.id ? coral : teal.withAlphaComponent(0.3); marker.lineWidth = selected == item.id ? 3 : 1
                group.addChild(marker)
                let text = SKLabelNode(text: ready ? "+" : "·"); text.fontName = "AvenirNext-Bold"; text.fontSize = 18; text.fontColor = teal; text.verticalAlignmentMode = .center
                group.addChild(text)
            }
            if selected == item.id {
                let ring = shape(.ellipse, rect: CGRect(x: -22,y: -10,width: 44,height: 20), color: .clear)
                ring.strokeColor = cream; ring.lineWidth = 2; group.addChild(ring)
            }
        }
    }
    private func tree(at point: CGPoint, into parent: SKNode) {
        let group = SKNode(); group.position = point; parent.addChild(group)
        group.addChild(shape(rect: CGRect(x: -3,y: 0,width: 6,height: 22), color: wood))
        for index in 0..<3 {
            group.addChild(polygon([CGPoint(x: -15 + CGFloat(index)*3,y: 11 + CGFloat(index)*10), CGPoint(x: 15 - CGFloat(index)*3,y: 11 + CGFloat(index)*10), CGPoint(x: 0,y: 37 + CGFloat(index)*8)], color: index % 2 == 0 ? teal : SKColor(red: 0.28,green: 0.54,blue: 0.35,alpha: 1)))
        }
    }
    private var rewardTextures: [DecorationID: SKTexture] = [:]

    private func draw(_ id: DecorationID, into node: SKNode) {
        let groundShadow = shape(.ellipse, rect: CGRect(x: -23,y: -10,width: 46,height: 18), color: teal.withAlphaComponent(0.15)); node.addChild(groundShadow)
        if let name = IslandRewardArt.name(for: id) {
            if rewardTextures[id] == nil, let image = UIImage(named: name) {
                rewardTextures[id] = SKTexture(image: image)
            }
            if let texture = rewardTextures[id] {
                let art = SKSpriteNode(texture: texture)
                let bounds: CGSize
                switch id {
                case .lighthouse: bounds = CGSize(width: 53, height: 78)
                case .windmill: bounds = CGSize(width: 59, height: 66)
                case .cottage, .trees: bounds = CGSize(width: 61, height: 57)
                case .fountain: bounds = CGSize(width: 51, height: 47)
                default: bounds = CGSize(width: 63, height: 39)
                }
                let dimensions = texture.size()
                let scale = min(bounds.width / dimensions.width, bounds.height / dimensions.height)
                art.size = CGSize(width: dimensions.width * scale, height: dimensions.height * scale)
                art.anchorPoint = CGPoint(x: 0.5, y: 0)
                art.position.y = -9
                art.zPosition = 1
                node.addChild(art)
                return
            }
        }
        switch id {
        case .pathways:
            for offset in -2...2 {
                let tile = polygon([CGPoint(x: -9,y: 0),CGPoint(x: 0,y: 5),CGPoint(x: 9,y: 0),CGPoint(x: 0,y: -5)], color: cream)
                tile.position = CGPoint(x: CGFloat(offset)*12, y: CGFloat(offset)*6); node.addChild(tile)
            }
        case .trees:
            tree(at: CGPoint(x: -12,y: 3), into: node); tree(at: CGPoint(x: 13,y: -3), into: node)
        case .flowerGarden:
            node.addChild(shape(rect: CGRect(x: -23,y: -8,width: 46,height: 21), color: wood, radius: 7))
            for row in 0..<2 { for column in 0..<4 {
                let x = CGFloat(column)*11 - 17, y = CGFloat(row)*9 - 1
                node.addChild(line([CGPoint(x: x,y: y),CGPoint(x: x,y: y + 8)], color: teal))
                for petal in 0..<5 {
                    let angle = CGFloat(petal) * .pi*2/5
                    node.addChild(shape(.ellipse, rect: CGRect(x: x + cos(angle)*3 - 2,y: y + 8 + sin(angle)*3 - 2,width: 4,height: 4), color: (column + row) % 2 == 0 ? coral : .systemYellow))
                }
            } }
        case .cottage:
            node.addChild(polygon([CGPoint(x: -22,y: 0),CGPoint(x: 7,y: -11),CGPoint(x: 7,y: 23),CGPoint(x: -22,y: 32)], color: cream))
            node.addChild(polygon([CGPoint(x: 7,y: -11),CGPoint(x: 27,y: 2),CGPoint(x: 27,y: 35),CGPoint(x: 7,y: 23)], color: SKColor(red: 0.85,green: 0.75,blue: 0.54,alpha: 1)))
            node.addChild(polygon([CGPoint(x: -28,y: 30),CGPoint(x: -3,y: 53),CGPoint(x: 33,y: 34),CGPoint(x: 8,y: 18)], color: coral))
            node.addChild(shape(rect: CGRect(x: -12,y: 1,width: 9,height: 17), color: wood, radius: 2))
            node.addChild(shape(rect: CGRect(x: 13,y: 10,width: 8,height: 10), color: .white, radius: 1))
            node.addChild(shape(rect: CGRect(x: -18,y: 39,width: 6,height: 13), color: cream, radius: 1))
        case .bridge, .dock:
            let isBridge = id == .bridge
            for index in -3...3 {
                let x = CGFloat(index)*7, y = isBridge ? 7 - abs(CGFloat(index))*2 : CGFloat(index)*2
                node.addChild(shape(rect: CGRect(x: x - 3,y: y - 6,width: 6,height: 20), color: index % 2 == 0 ? wood : cream, radius: 1))
            }
            for side in [-1,1] {
                node.addChild(line([CGPoint(x: -25,y: CGFloat(side)*8),CGPoint(x: -25,y: 19 + CGFloat(side)*8),CGPoint(x: 25,y: 19 + CGFloat(side)*8),CGPoint(x: 25,y: CGFloat(side)*8)], color: wood, width: 3))
            }
            if !isBridge { node.addChild(shape(.ellipse, rect: CGRect(x: 17,y: -4,width: 10,height: 13), color: .white)) }
        case .picnic:
            node.addChild(polygon([CGPoint(x: -22,y: 2),CGPoint(x: 0,y: 12),CGPoint(x: 23,y: 1),CGPoint(x: 0,y: -10)], color: coral.withAlphaComponent(0.75)))
            node.addChild(line([CGPoint(x: -9,y: -1),CGPoint(x: -9,y: 11),CGPoint(x: 10,y: 11),CGPoint(x: 10,y: -1)], color: wood, width: 4))
            node.addChild(shape(rect: CGRect(x: -17,y: 10,width: 34,height: 7), color: cream))
            node.addChild(line([CGPoint(x: 16,y: 0),CGPoint(x: 16,y: 38)], color: wood))
            node.addChild(polygon([CGPoint(x: -4,y: 29),CGPoint(x: 16,y: 43),CGPoint(x: 36,y: 29)], color: coral))
        case .fountain:
            node.addChild(shape(.ellipse, rect: CGRect(x: -24,y: -9,width: 48,height: 22), color: cream))
            node.addChild(shape(.ellipse, rect: CGRect(x: -20,y: -5,width: 40,height: 15), color: sea))
            node.addChild(shape(rect: CGRect(x: -4,y: 0,width: 8,height: 26), color: cream))
            node.addChild(shape(.ellipse, rect: CGRect(x: -12,y: 20,width: 24,height: 10), color: sea))
            for index in 0..<3 {
                let drop = shape(.ellipse, rect: CGRect(x: CGFloat(index - 1)*8 - 2,y: 24,width: 4,height: 9), color: .white)
                node.addChild(drop)
                if !reduceMotion { drop.run(.repeatForever(.sequence([.moveBy(x: 0,y: 10,duration: 0.65),.moveBy(x: 0,y: -10,duration: 0.65)]))) }
            }
        case .windmill:
            node.addChild(polygon([CGPoint(x: -17,y: 0),CGPoint(x: 17,y: 0),CGPoint(x: 10,y: 50),CGPoint(x: -10,y: 50)], color: cream))
            node.addChild(polygon([CGPoint(x: -14,y: 48),CGPoint(x: 0,y: 63),CGPoint(x: 14,y: 48)], color: coral))
            let blades = SKNode(); blades.position.y = 42; node.addChild(blades)
            for index in 0..<4 {
                let blade = shape(rect: CGRect(x: 0,y: 0,width: 5,height: 27), color: wood, radius: 1)
                blade.zRotation = CGFloat(index) * .pi/2; blades.addChild(blade)
            }
            if !reduceMotion { blades.run(.repeatForever(.rotate(byAngle: .pi*2,duration: 9))) }
        case .lighthouse:
            for index in 0..<4 { node.addChild(shape(rect: CGRect(x: -11 + CGFloat(index),y: CGFloat(index)*13,width: 22 - CGFloat(index)*2,height: 14), color: index % 2 == 0 ? cream : coral)) }
            node.addChild(shape(rect: CGRect(x: -10,y: 52,width: 20,height: 12), color: .systemYellow))
            node.addChild(polygon([CGPoint(x: -15,y: 64),CGPoint(x: 0,y: 77),CGPoint(x: 15,y: 64)], color: teal))
            let glow = shape(.ellipse, rect: CGRect(x: -19,y: 47,width: 38,height: 25), color: .systemYellow.withAlphaComponent(0.14)); node.addChild(glow)
            if !reduceMotion { glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25,duration: 1.5),.fadeAlpha(to: 1,duration: 1.5)]))) }
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: world) else { return }
        // Tall roofs and windmill blades are selectable too, not just their ground plot.
        for node in world.children.sorted(by: { $0.zPosition > $1.zPosition }) {
            if let name = node.name, let id = DecorationID(rawValue: name), node.calculateAccumulatedFrame().contains(location) {
                onSelect?(id); return
            }
        }
        guard let nearest = sites.min(by: {
            hypot($0.value.x - location.x, $0.value.y - location.y) < hypot($1.value.x - location.x, $1.value.y - location.y)
        }), hypot(nearest.value.x - location.x, nearest.value.y - location.y) < 32 else { return }
        onSelect?(nearest.key)
    }
}

@MainActor
final class IslandBoardModel: ObservableObject {
    let scene = IslandScene(size: CGSize(width: 390, height: 330))
    @Published var selected: DecorationID?
    init() { scene.scaleMode = .resizeFill; scene.onSelect = { [weak self] in self?.selected = $0 } }
}
