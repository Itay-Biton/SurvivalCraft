import GameplayKit

class Pathfinder {
    private let width: Int
    private let height: Int
    private let map: GameMap
    private var graph: GKGridGraph<GKGridGraphNode>
    private var nodeGrid: [[GKGridGraphNode?]]

    init(map: GameMap) {
        self.map = map
        self.width = map.width
        self.height = map.height

        graph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                            width: Int32(width),
                            height: Int32(height),
                            diagonalsAllowed: true,
                            nodeClass: GKGridGraphNode.self)

        // Init grid for fast access
        nodeGrid = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                let pos = vector_int2(Int32(x), Int32(y))
                if let node = graph.node(atGridPosition: pos) {
                    nodeGrid[y][x] = node
                    if !map.isWalkable(x: x, y: y) {
                        graph.remove([node])
                    }
                }
            }
        }
    }

    /// Update pathfinding graph after terrain or objects changed
    func updateTile(x: Int, y: Int) {
        guard map.isWalkable(x: x, y: y),
              let node = nodeGrid[y][x] else { return }

        if graph.node(atGridPosition: node.gridPosition) == nil {
            graph.add([node])
            graph.connectToAdjacentNodes(node: node)
        } else {
            graph.remove([node])
        }
    }

    /// Finds path between two tiles using A*
    func findPath(from start: vector_int2, to end: vector_int2) -> [vector_int2] {
        guard let startNode = graph.node(atGridPosition: start),
              let endNode = graph.node(atGridPosition: end) else {
            return []
        }

        let path = graph.findPath(from: startNode, to: endNode) as? [GKGridGraphNode] ?? []
        return path.map { $0.gridPosition }
    }
    
    func rebuildFromMap(_ map: GameMap) {
        // Remove all nodes first
        graph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                            width: Int32(map.width),
                            height: Int32(map.height),
                            diagonalsAllowed: true,
                            nodeClass: GKGridGraphNode.self)

        // Reset node grid
        nodeGrid = Array(repeating: Array(repeating: nil, count: map.width), count: map.height)

        // Recreate nodes and remove blocked ones
        for y in 0..<map.height {
            for x in 0..<map.width {
                let pos = vector_int2(Int32(x), Int32(y))
                if let node = graph.node(atGridPosition: pos) {
                    nodeGrid[y][x] = node
                    // If tile is NOT walkable, remove it from the graph
                    if !map.isWalkable(x: x, y: y) {
                        graph.remove([node])
                    }
                }
            }
        }
    }
    
    /// Find the nearest walkable tile around a blocked tile (object position).
    func findNearestWalkableAround(x: Int, y: Int, searchRadius: Int = 2) -> vector_int2? {
        // Search from radius 1 up to `searchRadius`
        for radius in 1...searchRadius {
            for offsetY in -radius...radius {
                for offsetX in -radius...radius {
                    let nx = x + offsetX
                    let ny = y + offsetY

                    // Skip the center tile itself
                    if nx == x && ny == y { continue }

                    // Skip out of bounds
                    if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }

                    // If walkable → return immediately
                    if map.isWalkable(x: nx, y: ny),
                       graph.node(atGridPosition: vector_int2(Int32(nx), Int32(ny))) != nil {
                        return vector_int2(Int32(nx), Int32(ny))
                    }
                }
            }
        }

        // No valid tile found
        return nil
    }
}
