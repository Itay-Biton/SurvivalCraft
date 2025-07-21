import Foundation

class GameMap {
    struct Tile {
        var floor: FloorKind
        var object: PlacedObject?
    }

    let width: Int
    let height: Int
    private(set) var tiles: [[Tile]]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.tiles = Array(
            repeating: Array(repeating: Tile(floor: .land, object: nil), count: width),
            count: height
        )
    }

    func setFloor(x: Int, y: Int, kind: FloorKind) {
        guard isValid(x: x, y: y) else { return }
        tiles[y][x].floor = kind
    }

    func getFloor(x: Int, y: Int) -> FloorKind? {
        guard isValid(x: x, y: y) else { return nil }
        return tiles[y][x].floor
    }

    func canPlaceObject(_ definition: ObjectDefinition, atX x: Int, y: Int) -> Bool {
        for dx in 0..<definition.size.width {
            for dy in 0..<definition.size.height {
                let tx = x + dx
                let ty = y + dy
                if !isValid(x: tx, y: ty) { return false }
                let tile = tiles[ty][tx]
                
                if tile.object != nil { return false }
                
                if tile.floor != .land { return false }
            }
        }
        return true
    }

    func placeObject(_ definition: ObjectDefinition, atX x: Int, y: Int) {
        let placed = PlacedObject(kind: definition.kind, origin: (x, y))
        for dx in 0..<definition.size.width {
            for dy in 0..<definition.size.height {
                let tx = x + dx
                let ty = y + dy
                if isValid(x: tx, y: ty) {
                    tiles[ty][tx].object = placed
                }
            }
        }
    }

    func getObject(atX x: Int, y: Int) -> PlacedObject? {
        guard isValid(x: x, y: y) else { return nil }
        return tiles[y][x].object
    }

    func isWalkable(x: Int, y: Int) -> Bool {
        guard isValid(x: x, y: y) else { return false }
        let tile = tiles[y][x]
        let floorWalkable = FloorDatabase.all[tile.floor]?.isWalkable ?? false
        let objectBlocks = tile.object?.isBlocking(x: x, y: y) ?? false
        return floorWalkable && !objectBlocks
    }

    func isValid(x: Int, y: Int) -> Bool {
        return x >= 0 && x < width && y >= 0 && y < height
    }
    
    func removeObject(atX x: Int, y: Int) {
        guard isValid(x: x, y: y) else { return }
        tiles[y][x].object = nil
    }
}
