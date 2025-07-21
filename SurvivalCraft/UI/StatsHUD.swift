import SpriteKit

class StatsHUD: SKNode {
    private let healthBar = SKSpriteNode(color: .red, size: CGSize(width: 100, height: 10))
    private let hungerBar = SKSpriteNode(color: .orange, size: CGSize(width: 100, height: 10))
    
    private let barBackgroundColor = SKColor(white: 0.2, alpha: 1.0)
    private let backgroundBox = SKShapeNode(rectOf: CGSize(width: 110, height: 32), cornerRadius: 6)

    override init() {
        super.init()

        backgroundBox.fillColor = barBackgroundColor
        backgroundBox.strokeColor = .clear
        backgroundBox.zPosition = 1000
        addChild(backgroundBox)

        // Set left anchor so we can scale width from the left
        healthBar.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        hungerBar.anchorPoint = CGPoint(x: 0.0, y: 0.5)

        // Center vertically with spacing between bars
        healthBar.position = CGPoint(x: -50, y: 6)
        hungerBar.position = CGPoint(x: -50, y: -6)

        healthBar.zPosition = 1001
        hungerBar.zPosition = 1001

        addChild(healthBar)
        addChild(hungerBar)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with stats: PlayerStats) {
        healthBar.xScale = CGFloat(stats.health) / CGFloat(stats.maxHealth)
        hungerBar.xScale = CGFloat(stats.hunger) / CGFloat(stats.maxHunger)
    }
}
