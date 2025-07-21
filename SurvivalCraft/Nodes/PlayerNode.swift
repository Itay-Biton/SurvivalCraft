import SpriteKit

import SpriteKit

struct PlayerStats {
    var health: Int = 100
    var maxHealth: Int = 100

    var hunger: Int = 100
    var maxHunger: Int = 100

    private var hungerAccumulator: TimeInterval = 0
    private var healthAccumulator: TimeInterval = 0

    mutating func update(deltaTime: TimeInterval) {
        // Slower hunger drain: every 3 seconds lose 1 point
        hungerAccumulator += deltaTime
        if hungerAccumulator >= 3.0 {
            let ticks = Int(hungerAccumulator / 3.0)
            hunger = max(hunger - ticks, 0)
            hungerAccumulator -= Double(ticks) * 3.0
        }

        // Slower health change: every 5 seconds change by 1
        healthAccumulator += deltaTime
        if healthAccumulator >= 5.0 {
            let ticks = Int(healthAccumulator / 5.0)
            if hunger <= 0 {
                health = max(health - 2 * ticks, 0) // starving damage
            } else if health < maxHealth {
                health = min(health + ticks, maxHealth) // regeneration
            }
            healthAccumulator -= Double(ticks) * 5.0
        }
    }
}

class PlayerNode: SKSpriteNode {

    var direction: Direction = .right {
        didSet {
            // Ignore up/down directions
            if direction == .up || direction == .down {
                direction = oldValue
            }
        }
    }
    var isWalking = false
    private var lastDirection: Direction?
    private var lastIsWalking: Bool?
    private var lastAnimationKey: String?

    let inventory = Inventory()
    var stats = PlayerStats()

    init(position: CGPoint) {
        let initialTexture = SKTexture(imageNamed: "player_idle1 1")
        super.init(texture: initialTexture, color: .clear, size: initialTexture.size())

        self.position = position
        self.name = "player"
        self.zPosition = 2
        self.speed = 200.0

        updateFacing()
        updateAnimationIfNeeded()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAnimationPaused(_ paused: Bool) {
        // This pauses/resumes ALL actions (animations) on the player
        self.isPaused = paused
    }
    
    // MARK: - Texture Loading
    static func loadWalkTextures() -> [SKTexture] {
        return (1...8).map { SKTexture(imageNamed: "player_walking\($0) 1") }
    }

    static func loadIdleTextures() -> [SKTexture] {
        return (1...4).map { SKTexture(imageNamed: "player_idle\($0) 1") }
    }

        // MARK: - Animation Control
    func updateAnimationIfNeeded() {
        updateFacing()
        // ✅ Skip if state didn’t change
        if direction == lastDirection && isWalking == lastIsWalking {
            return
        }
        
        lastDirection = direction
        lastIsWalking = isWalking
        
        let newKey = isWalking ? "walk" : "idle"
        
        // ✅ Already running this animation? Skip restart
        if lastAnimationKey == newKey, action(forKey: newKey) != nil {
            return
        }
        
        // ✅ If we’re switching keys, stop only the previous one
        if let lastKey = lastAnimationKey {
            removeAction(forKey: lastKey)
        }
        
        lastAnimationKey = newKey
        
        // ✅ Pick correct textures once
        let textures: [SKTexture] = isWalking
            ? PlayerNode.loadWalkTextures()
            : PlayerNode.loadIdleTextures()
        
        // ✅ Timing is in seconds
        let frameTime: TimeInterval = isWalking ? 20 : 35
        
        let frames = textures.map { tex -> SKAction in
            SKAction.group([
                SKAction.setTexture(tex, resize: false),
                SKAction.wait(forDuration: frameTime)
            ])
        }
        
        let animation = SKAction.repeatForever(SKAction.sequence(frames))
        run(animation, withKey: newKey)
    }
    
    // MARK: - Facing Direction
    func updateFacing() {
        switch direction {
        case .left:
            xScale = -1.0
        default:
            xScale = 1.0
        }
    }

    // MARK: - Eating
    func eat(item: InventoryItemType) -> Bool {
        guard let gameItem = GameItemRegistry.allItems[item],
              let restore = gameItem.restoreHunger,
              let slotIndex = inventory.getFirstIndex(of: item)
        else {
            return false
        }

        inventory.remove(at: slotIndex, amount: 1)
        stats.hunger = min(stats.hunger + restore, stats.maxHunger)
        return true
    }

    // MARK: - Interact
    func interact(
        at point: CGPoint,
        tileSize: CGSize,
        map: GameMap,
        pathfinder: Pathfinder,
        scene: GameScene,
        viewController: GameViewController?
    ) -> Bool {
        let column = Int(point.x / tileSize.width)
        let row = map.height - 1 - Int(point.y / tileSize.height)

        guard map.isValid(x: column, y: row),
              let object = map.getObject(atX: column, y: row),
              object.isInteractable(x: column, y: row) else {
            return false
        }

        // Check distance
        let playerDistance = hypot(position.x - point.x, position.y - point.y)
        guard playerDistance <= 48 else { return false }

        // Resolve gatherable item
        guard let drop = GameItemRegistry.tileGathers[object.kind] else { return false }
        let itemData = GameItemRegistry.get(drop.item)

        // Check equipped tool
        var equippedTool: InventoryItemType? = nil
        var equippedToolSlotIndex: Int? = nil

        if let index = viewController?.selectedHotbarIndex,
           index < inventory.slots.count,
           let toolType = inventory.slots[index].type {
            equippedTool = toolType
            equippedToolSlotIndex = index
        }

        guard GameItemRegistry.canGather(object: object.kind, using: equippedTool) else { return false }

        // Calculate yield
        let yield = itemData.calculateYield(using: equippedTool, baseYield: drop.baseYield)
        guard yield > 0 else { return false }

        // Add items and update durability
        inventory.add(itemData.id, amount: yield)
        if let toolIndex = equippedToolSlotIndex {
            inventory.decreaseDurability(at: toolIndex)
        }

        // Remove visuals and update map
        let occupied = object.definition.occupiedOffsets
        for offset in occupied {
            let tx = object.origin.x + offset.x
            let ty = object.origin.y + offset.y
            if map.isValid(x: tx, y: ty) {
                map.removeObject(atX: tx, y: ty)

                let key = vector_int2(Int32(tx), Int32(ty))
                if let visual = scene.objectVisuals.removeValue(forKey: key) {
                    visual.removeFromParent()
                }
            }
        }

        let interactable = object.definition.interactableOffsets
        for offset in interactable {
            let tx = object.origin.x + offset.x
            let ty = object.origin.y + offset.y
            if map.isValid(x: tx, y: ty) {
                pathfinder.updateTile(x: tx, y: ty)
            }
        }

        return true
    }
}

enum Direction: String {
    case up, down, left, right
}
