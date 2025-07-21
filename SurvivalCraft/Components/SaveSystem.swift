import Foundation
import CoreGraphics

// MARK: - Models

struct SaveSlot: Codable {
    let item: String
    let count: Int
    let durability: Int?
}
struct InventorySlotCodable: Codable {
    var item: String?
    var count: Int
    var durability: Int?
}
struct FloorTileSave: Codable {
    let x: Int
    let y: Int
    let kind: String // e.g. "land", "water"
}
struct ObjectSaveData: Codable {
    let x: Int
    let y: Int
    let kind: String // object ID
}
struct AnimalSaveData: Codable {
    let kind: String
    let posX: CGFloat
    let posY: CGFloat
}

struct GameSaveData: Codable {
    let version: Int
    let worldName: String
    let timestamp: Date
    
    let playerPositionX: CGFloat
    let playerPositionY: CGFloat
    let health: Int
    let hunger: Int
    let inventorySlots: [InventorySlotCodable]
    let selectedHotbarIndex: Int
    
    let mapTiles: [FloorTileSave]
    let objects: [ObjectSaveData]
    
    // ✅ NEW: Save all animals
    let animals: [AnimalSaveData]
}

// MARK: - Save System

class SaveSystem {
    
    static let shared = SaveSystem()
    private init() {}
    
    private let saveKeyPrefix = "gameSave_"
    
    /// Returns all saved world names
    func listSaves() -> [String] {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        return keys.filter { $0.hasPrefix(saveKeyPrefix) }
            .map { $0.replacingOccurrences(of: saveKeyPrefix, with: "") }
    }
    
    /// Save a given world
    func saveGame(worldName: String, saveData: GameSaveData) {
        if let encoded = try? JSONEncoder().encode(saveData) {
            UserDefaults.standard.set(encoded, forKey: saveKeyPrefix + worldName)
            print("✅ Saved world: \(worldName)")
        } else {
            print("❌ Failed to encode save data for world: \(worldName)")
        }
    }
    
    /// Load a given world
    func loadGame(worldName: String) -> GameSaveData? {
        let key = saveKeyPrefix + worldName
        
//        listSaves().forEach { deleteGame(worldName: $0) }
//        return nil
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            print("ℹ️ No save found for world: \(worldName)")
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(GameSaveData.self, from: data)

            if decoded.version < 2 {
                print("⚠️ Save file is old (v\(decoded.version)), deleting…")
                deleteGame(worldName: key)
                return nil
            }

            print("✅ Loaded world: \(worldName) successfully")
            return decoded

        } catch {
            print("❌ Failed to decode save: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Delete a given save
    func deleteGame(worldName: String) {
        UserDefaults.standard.removeObject(forKey: saveKeyPrefix + worldName)
        print("🗑 Deleted save: \(worldName)")
    }
}
