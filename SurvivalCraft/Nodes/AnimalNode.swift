import CoreGraphics
import SpriteKit

enum AnimalAnimationType {
    case idle
    case walk
    case attack
    case hit
    case death
}

enum AnimalKind: String, CaseIterable {
    case cow
    case skeleton
    
    var idleFrames: [String] {
        switch self {
        case .cow: return (1...4).map { "cow\($0)" }
        case .skeleton: return (1...6).map { "skeleton_idle\($0)" }
        }
    }
    
    var walkFrames: [String] {
        switch self {
        case .cow: return (1...4).map { "cow\($0)" }
        case .skeleton: return (1...8).map { "skeleton_walk\($0)" }
        }
    }
    
    var attackFrames: [String] {
        switch self {
        case .cow: return [] // cows don’t attack
        case .skeleton: return (1...7).map { "skeleton_attack\($0)" }
        }
    }
    
    var hitFrames: [String] {
        switch self {
        case .cow: return ["cow1"]
        case .skeleton: return (1...7).map { "skeleton_hit\($0)" }
        }
    }
    
    var deathFrames: [String] {
        switch self {
        case .cow: return (1...4).map { "cow\($0)" }
        case .skeleton: return (1...3).map { "skeleton_hit\($0)" }
        }
    }
    
    var idleSpeed: TimeInterval { 0.25 }
    var walkSpeed: TimeInterval { 0.15 }
    var attackSpeed: TimeInterval { 0.1 }
    var hitSpeed: TimeInterval { 0.12 }
    var deathSpeed: TimeInterval { 0.15 }
    
    var speed: CGFloat {
        switch self {
        case .cow: return 20
        case .skeleton: return 50
        }
    }
    
    var isHostile: Bool {
        return self == .skeleton
    }
    
    var maxHealth: Int {
        switch self {
        case .cow: return 30
        case .skeleton: return 50
        }
    }
    
    var attackDamage: Int {
        switch self {
        case .cow: return 0
        case .skeleton: return 5
        }
    }
    
    var attackCooldown: TimeInterval { 1.0 }
    
    /// Possible drops: (item, drop chance %)
    var dropTable: [(item: InventoryItemType, dropChance: Double)] {
        switch self {
        case .cow:
            return [
                (.wood, 0.50),  // 50% chance wood
                (.stone, 0.20) // 20% chance stone
            ]
        case .skeleton:
            return [
                (.berry, 0.75),
            ] // no drops
        }
    }
}

class AnimalNode: SKSpriteNode {
    let kind: AnimalKind
    weak var gameScene: GameScene?
    
    var moveDirection: CGVector = .zero
    var moveCooldown: TimeInterval = 0
    
    private(set) var currentAnimation: AnimalAnimationType = .idle
    
    private var health: Int
    private var isDead: Bool = false
    
    private var attackCooldownTimer: TimeInterval = 0
    
    init(kind: AnimalKind) {
        self.kind = kind
        self.health = kind.maxHealth
        
        let initialTexture = SKTexture(imageNamed: kind.idleFrames.first!)
        super.init(texture: initialTexture, color: .clear, size: CGSize(width: 32, height: 32))
        
        zPosition = 2
        name = "animal_\(kind.rawValue)"
        
        playAnimation(.idle)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func die() {
        guard !isDead else { return }
        isDead = true
        
        print("💀 \(kind.rawValue) died")
        removeAllActions()
        
        if !kind.deathFrames.isEmpty {
            playAnimation(.death)
        } else {
            dropLoot()
            removeFromParent()
            gameScene?.removeAnimal(self) // ✅ inform GameScene
        }
    }

    func playAnimation(_ type: AnimalAnimationType) {
        guard !isDead || type == .death else { return }
        guard currentAnimation != type else { return }
        currentAnimation = type
        
        removeAction(forKey: "animation")
        
        let frames: [SKTexture]
        let speed: TimeInterval
        
        switch type {
        case .idle: frames = kind.idleFrames.map { SKTexture(imageNamed: $0) }; speed = kind.idleSpeed
        case .walk: frames = kind.walkFrames.map { SKTexture(imageNamed: $0) }; speed = kind.walkSpeed
        case .attack: frames = kind.attackFrames.map { SKTexture(imageNamed: $0) }; speed = kind.attackSpeed
        case .hit: frames = kind.hitFrames.map { SKTexture(imageNamed: $0) }; speed = kind.hitSpeed
        case .death: frames = kind.deathFrames.map { SKTexture(imageNamed: $0) }; speed = kind.deathSpeed
        }
        
        // No frames → skip
        if frames.isEmpty {
            if type == .death {
                dropLoot()
                run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.removeFromParent()
                ]))
            }
            return
        }
        
        let animateAction = SKAction.animate(with: frames, timePerFrame: speed, resize: false, restore: false)
        
        switch type {
        case .idle, .walk:
            run(SKAction.repeatForever(animateAction), withKey: "animation")
            
        case .attack:
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.2),
                animateAction,
                SKAction.wait(forDuration: 0.3),
                SKAction.run { [weak self] in self?.onAttackFinished() }
            ]), withKey: "animation")
            
        case .hit:
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                animateAction,
                SKAction.wait(forDuration: 0.2),
                SKAction.run { [weak self] in self?.playAnimation(.idle) }
            ]), withKey: "animation")
            
        case .death:
            run(SKAction.sequence([
                animateAction,
                SKAction.run { [weak self] in self?.dropLoot() },
                SKAction.wait(forDuration: 2.0), // keep corpse 2 sec
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.run { [weak self] in
                    if let self = self {
                        self.gameScene?.removeAnimal(self)
                    }
                },
                SKAction.removeFromParent()
            ]), withKey: "animation")
        }
    }
    
    private func onAttackFinished() {
        guard let scene = gameScene, !isDead else { return }
        
        attackCooldownTimer = kind.attackCooldown
        
        // Try to damage player if still in range
        if let player = scene.player {
            let dist = hypot(player.position.x - position.x, player.position.y - position.y)
            if dist < 60 {
                // deal damage to player
                player.stats.health -= kind.attackDamage
                print("⚔️ \(kind.rawValue) hit the player! Player HP: \(player.stats.health)")
            }
        }
        
        playAnimation(.idle)
    }
    
    func update(deltaTime: TimeInterval) {
        guard let scene = gameScene else { return }
        guard !isDead else { return }
        
        // Reduce timers
        moveCooldown -= deltaTime
        attackCooldownTimer -= deltaTime
        
        // ✅ If currently attacking or hit → wait
        if currentAnimation == .attack || currentAnimation == .hit {
            return
        }
        
        var isMoving = false
        
        // ✅ Hostile animals (like skeleton) have PRIORITY to check player every frame
        if kind.isHostile, let player = scene.player {
            let dist = hypot(player.position.x - position.x, player.position.y - position.y)
            
            // ✅ 1) If in attack range, stop everything & attack
            if dist < 60 && attackCooldownTimer <= 0 {
                playAnimation(.attack)
                return
            }
            
            // ✅ 2) If in chase distance, immediately follow player
            if dist < 150 {
                moveDirection = CGVector(dx: player.position.x - position.x,
                                         dy: player.position.y - position.y).normalized()
                isMoving = true
            } else if moveCooldown <= 0 {
                // ✅ Otherwise wander randomly after cooldown
                moveCooldown = Double.random(in: 2...4)
                let angle = CGFloat.random(in: 0...(2 * .pi))
                moveDirection = CGVector(dx: cos(angle), dy: sin(angle))
                isMoving = true
            }
            
        } else {
            // ✅ Passive animals like cow: flee or wander
            
            if let player = scene.player {
                let dist = hypot(player.position.x - position.x, player.position.y - position.y)
                
                if !kind.isHostile && dist < 120 {
                    // ✅ Cow flees immediately when close
                    moveDirection = CGVector(dx: position.x - player.position.x,
                                             dy: position.y - player.position.y).normalized()
                    isMoving = true
                } else if moveCooldown <= 0 {
                    // ✅ Otherwise wander randomly
                    moveCooldown = Double.random(in: 2...4)
                    let angle = CGFloat.random(in: 0...(2 * .pi))
                    moveDirection = CGVector(dx: cos(angle), dy: sin(angle))
                    isMoving = true
                }
            }
        }
        
        // ✅ Move step if we have a direction
        let step = kind.speed * CGFloat(deltaTime)
        let nextPos = CGPoint(
            x: position.x + moveDirection.dx * step,
            y: position.y + moveDirection.dy * step
        )
        
        if moveDirection != .zero { isMoving = true }
        
        // ✅ Collision check
        if scene.isPositionWalkable(nextPos) {
            position = nextPos
        } else {
            // blocked → pick new random direction quickly
            let angle = CGFloat.random(in: 0...(2 * .pi))
            moveDirection = CGVector(dx: cos(angle), dy: sin(angle))
            moveCooldown = 0.5
        }
        
        // ✅ Play correct animation
        if isMoving {
            playAnimation(.walk)
            // Flip sprite direction based on movement
            xScale = moveDirection.dx < 0 ? abs(xScale) : -abs(xScale)
        } else {
            playAnimation(.idle)
        }
    }
    
    func hitByPlayer(damage: Int) {
        guard !isDead else { return }
        
        health -= damage
        print("🐾 \(kind.rawValue) took \(damage) damage → \(health) HP left")
        
        if health <= 0 {
            die()
        } else {
            playAnimation(.hit)
        }
    }
    
    /// ✅ Drops loot based on dropTable probabilities & adds to inventory
    private func dropLoot() {
        guard let scene = gameScene, let player = scene.player else { return }
        
        print("🎁 Checking drops for \(kind.rawValue)")
        var lootObtained: [InventoryItemType] = []
        
        for drop in kind.dropTable {
            if Double.random(in: 0...1) < drop.dropChance {
                print("✅ \(kind.rawValue) dropped \(drop.item.rawValue)")
                
                // ✅ Add directly to player's inventory
                player.inventory.add(drop.item, amount: 1)
                lootObtained.append(drop.item)
                
                // ✅ Spawn a quick floating label for feedback
                let dropNode = SKLabelNode(text: "+ \(drop.item.rawValue.capitalized)")
                dropNode.fontName = "AvenirNext-Bold"
                dropNode.fontSize = 18
                dropNode.fontColor = .yellow
                dropNode.position = self.position
                dropNode.zPosition = 999
                
                scene.addChild(dropNode)
                
                dropNode.run(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 20, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.removeFromParent()
                ]))
            }
        }
        
        if lootObtained.isEmpty {
            print("❌ No loot dropped from \(kind.rawValue)")
        } else {
            // ✅ Trigger UI update (e.g., hotbar refresh)
            player.inventory.onChange?()
        }
    }
}

extension CGVector {
    func normalized() -> CGVector {
        let len = sqrt(dx * dx + dy * dy)
        return len > 0 ? CGVector(dx: dx / len, dy: dy / len) : .zero
    }
}
