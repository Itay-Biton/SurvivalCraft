import CoreGraphics

enum ObjectKind: String, CaseIterable {
    case tree, tree2, rock, rock_large, berry
}

enum InventoryItemType: String, CaseIterable, Codable {
    case wood
    case stone
    case berry
    case iron
    case axe
    case pickaxe
}

enum ToolType: String {
    case axe
    case pickaxe
    case none
}

struct ObjectDatabase {
    static func getDefinition(for rawKind: String) -> ObjectDefinition? {
        guard let kind = ObjectKind(rawValue: rawKind) else {
            print("⚠️ Unknown object kind in save: \(rawKind)")
            return nil
        }
        return ObjectDatabase.all[kind]
    }
    
    static let all: [ObjectKind: ObjectDefinition] = [
        .tree: ObjectDefinition(
            kind: .tree,
            size: (1, 2),
            interactableOffsets: [(0, 0)],
            textureName: "tree.png",
            anchor: CGPoint(x: 0.0, y: 0.0)
        ),
        .tree2: ObjectDefinition(
            kind: .tree2,
            size: (1, 2),
            interactableOffsets: [(0, 0)],
            textureName: "tree2.png",
            anchor: CGPoint(x: 0.0, y: 0.0)
        ),
        .rock: ObjectDefinition(
            kind: .rock,
            size: (1, 1),
            interactableOffsets: [(0, 0)],
            textureName: "rock.png",
            anchor: CGPoint(x: 0.0, y: 0.0)
        ),
        .rock_large: ObjectDefinition(
            kind: .rock_large,
            size: (2, 2),
            interactableOffsets: [(0, 0), (1, 0), (0, 1), (1, 1)],
            textureName: "rock_large.png",
            anchor: CGPoint(x: 0.0, y: 0.5)
        ),
        .berry: ObjectDefinition(
            kind: .berry,
            size: (1, 1),
            interactableOffsets: [(0, 0)],
            textureName: "bush.png",
            anchor: CGPoint(x: 0.0, y: 0.0)
        )
    ]
}

struct GameItemRegistry {
    static let allItems: [InventoryItemType: GameItem] = [
        .wood: GameItem(
            id: .wood,
            displayName: "Wood",
            toolRequired: .axe,
            toolOptional: true,
            toolRankRequired: 1,
            recipe: nil,
            defaultDurability: nil,
            restoreHunger: nil
        ),
        .stone: GameItem(
            id: .stone,
            displayName: "Stone",
            toolRequired: .pickaxe,
            toolOptional: true,
            toolRankRequired: 1,
            recipe: nil,
            defaultDurability: nil,
            restoreHunger: nil
        ),
        .berry: GameItem(
            id: .berry,
            displayName: "Berry",
            toolRequired: .axe,
            toolOptional: false,
            toolRankRequired: 1,
            recipe: nil,
            defaultDurability: nil,
            restoreHunger: 15
        ),
        .iron: GameItem(
            id: .iron,
            displayName: "Iron",
            toolRequired: nil,
            toolOptional: false,
            toolRankRequired: 1,
            recipe: nil,
            defaultDurability: nil,
            restoreHunger: nil
        ),
        .axe: GameItem(
            id: .axe,
            displayName: "Axe",
            toolRequired: .axe,
            toolOptional: true,
            toolRankRequired: 1,
            recipe: CraftingRecipe(
                result: .axe,
                amount: 1,
                ingredients: [.wood: 3]
            ),
            defaultDurability: 10,
            restoreHunger: nil
        ),
        .pickaxe: GameItem(
            id: .pickaxe,
            displayName: "Pickaxe",
            toolRequired: .pickaxe,
            toolOptional: true,
            toolRankRequired: 1,
            recipe: CraftingRecipe(
                result: .pickaxe,
                amount: 1,
                ingredients: [.wood: 3, .stone: 2]
            ),
            defaultDurability: 10,
            restoreHunger: nil
        )
    ]

    static let tileGathers: [ObjectKind: GatherableDrop] = [
        .tree: GatherableDrop(item: .wood, baseYield: 1),
        .tree2: GatherableDrop(item: .wood, baseYield: 1),
        .rock: GatherableDrop(item: .stone, baseYield: 1),
        .rock_large: GatherableDrop(item: .stone, baseYield: 2),
        .berry: GatherableDrop(item: .berry, baseYield: 1)
    ]

    static let gatherRequirements: [ObjectKind: ToolRequirement] = [
        .tree: ToolRequirement(required: .axe, optional: true, rank: 1),
        .tree2: ToolRequirement(required: .axe, optional: true, rank: 1),
        .rock: ToolRequirement(required: .pickaxe, optional: true, rank: 1),
        .rock_large: ToolRequirement(required: .pickaxe, optional: false, rank: 1),
        .berry: ToolRequirement(required: .axe, optional: false, rank: 1)
    ]

    static func get(_ type: InventoryItemType) -> GameItem {
        return allItems[type]!
    }

    static var allCraftable: [CraftingRecipe] {
        return allItems.values.compactMap { $0.recipe }
    }

    static func canGather(object: ObjectKind, using tool: InventoryItemType?) -> Bool {
        guard let req = gatherRequirements[object] else { return true }

        if req.required == nil {
            return true
        }

        guard let tool,
              let toolItem = allItems[tool],
              let toolType = toolItem.toolType else {
            return req.optional
        }

        if toolType != req.required {
            return req.optional
        }

        return toolItem.toolRank >= req.rank
    }
}

struct ObjectDefinition {
    let kind: ObjectKind
    let size: (width: Int, height: Int)
    let interactableOffsets: [(x: Int, y: Int)]
    let textureName: String
    let anchor: CGPoint

    var occupiedOffsets: [(x: Int, y: Int)] {
        (0..<size.width).flatMap { dx in
            (0..<size.height).map { dy in (x: dx, y: dy) }
        }
    }
}

struct CraftingRecipe {
    let result: InventoryItemType
    let amount: Int
    let ingredients: [InventoryItemType: Int]
}

struct GatherableDrop {
    let item: InventoryItemType
    let baseYield: Int
}

struct ToolRequirement {
    let required: ToolType?
    let optional: Bool
    let rank: Int
}

struct GameItem {
    let id: InventoryItemType
    let displayName: String
    let toolRequired: ToolType?
    let toolOptional: Bool
    let toolRankRequired: Int
    let recipe: CraftingRecipe?
    let defaultDurability: Int?
    let restoreHunger: Int?

    func calculateYield(using tool: InventoryItemType?, baseYield: Int = 1) -> Int {
        guard let tool = tool,
              let toolItem = GameItemRegistry.allItems[tool],
              let equippedToolType = toolItem.toolType else {
            return baseYield
        }

        let isCorrectTool = equippedToolType == toolRequired

        if let _ = toolRequired, !toolOptional {
            if !isCorrectTool {
                return baseYield
            }
            let bonus = toolItem.toolRank - toolRankRequired
            return baseYield * max(bonus + baseYield, baseYield)
        }

        if toolOptional {
            if isCorrectTool {
                return max(toolItem.toolRank + baseYield, baseYield)
            } else {
                return baseYield
            }
        }

        return baseYield
    }

    var toolType: ToolType? {
        ToolType(rawValue: id.rawValue)
    }

    var toolRank: Int {
        toolRequired == nil ? 0 : toolRankRequired
    }
}

