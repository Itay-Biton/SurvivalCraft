// MARK: - Inventory Class
class Inventory {
    var onChange: (() -> Void)?
    var slots: [InventorySlot] = Array(repeating: InventorySlot.empty, count: 35)

    func currentItems() -> [(InventoryItemType, Int)] {
        var counts: [InventoryItemType: Int] = [:]

        for slot in slots {
            if let type = slot.type, slot.count > 0 {
                counts[type, default: 0] += slot.count
            }
        }

        return counts.map { ($0.key, $0.value) }
    }

    func add(_ type: InventoryItemType, amount: Int = 1) {
        let itemData = GameItemRegistry.get(type)

        if let durability = itemData.defaultDurability {
            // Non-stackable tools: add one per slot
            for _ in 0..<amount {
                if let index = slots.firstIndex(where: { $0.isEmpty }) {
                    slots[index] = InventorySlot(type: type, count: 1, durability: durability)
                }
            }
        } else {
            // Stackable items
            if let index = slots.firstIndex(where: { $0.type == type }) {
                slots[index].count += amount
            } else if let index = slots.firstIndex(where: { $0.isEmpty }) {
                slots[index] = InventorySlot(type: type, count: amount)
            }
        }

        onChange?()
    }

    func moveItem(from sourceIndex: Int, to targetIndex: Int) {
        guard slots.indices.contains(sourceIndex),
              slots.indices.contains(targetIndex) else {
            print("❌ Invalid move: source=\(sourceIndex), target=\(targetIndex), slots.count=\(slots.count)")
            return
        }
        if sourceIndex == targetIndex {
            print("ℹ️ Same slot tapped")
            return
        }

        let temp = slots[sourceIndex]
        slots[sourceIndex] = slots[targetIndex]
        slots[targetIndex] = temp
        print("✅ Moved item from \(sourceIndex) → \(targetIndex)")
        onChange?()
    }

    func remove(at index: Int, amount: Int = 1) {
        guard slots.indices.contains(index), !slots[index].isEmpty else { return }
        if slots[index].count > amount {
            slots[index].count -= amount
        } else {
            slots[index] = .empty
        }
        onChange?()
    }

    func getFirstIndex(of type: InventoryItemType) -> Int? {
        return slots.firstIndex { $0.type == type && !$0.isEmpty }
    }

    func count(of type: InventoryItemType) -> Int {
        return slots.filter { $0.type == type }.map { $0.count }.reduce(0, +)
    }
    
    func has(_ item: InventoryItemType, amount: Int = 1) -> Bool {
        return slots.contains { slot in
            slot.type == item && slot.count >= amount
        }
    }
}

// MARK: - Crafting Support
extension Inventory {
    func canCraft(_ recipe: CraftingRecipe) -> Bool {
        for (item, requiredCount) in recipe.ingredients {
            if count(of: item) < requiredCount {
                return false
            }
        }
        return true
    }

    func craft(_ recipe: CraftingRecipe) -> Bool {
        guard canCraft(recipe) else { return false }

        for (item, countNeeded) in recipe.ingredients {
            var remaining = countNeeded
            for index in 0..<slots.count where slots[index].type == item && remaining > 0 {
                let used = min(slots[index].count, remaining)
                slots[index].count -= used
                remaining -= used
                if slots[index].count <= 0 {
                    slots[index] = .empty
                }
            }
        }

        add(recipe.result, amount: recipe.amount)
        onChange?()
        return true
    }
    
    func decreaseDurability(at index: Int) {
        guard slots.indices.contains(index), !slots[index].isEmpty else { return }

        var slot = slots[index]
        if let currentDurability = slot.durability {
            let newValue = currentDurability - 1
            if newValue <= 0 {
                print("💥 Tool at slot \(index) broke.")
                slots[index] = .empty
            } else {
                slot.durability = newValue
                slots[index] = slot
            }
            onChange?()
        }
    }
}

// MARK: - Inventory Slot
struct InventorySlot {
    var type: InventoryItemType?
    var count: Int
    var durability: Int?

    var isEmpty: Bool {
        return type == nil || count <= 0
    }

    static let empty = InventorySlot(type: nil, count: 0, durability: nil)
}
