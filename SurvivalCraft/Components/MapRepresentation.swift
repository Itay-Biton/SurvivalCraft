struct PlacedObject {
    let kind: ObjectKind
    let origin: (x: Int, y: Int)

    var definition: ObjectDefinition {
        return ObjectDatabase.all[kind]!
    }

    var occupiedOffsets: [(x: Int, y: Int)] {
        let def = definition
        return (0..<def.size.width).flatMap { dx in
            (0..<def.size.height).map { dy in
                (x: dx, y: dy)
            }
        }
    }

    var interactableOffsets: [(x: Int, y: Int)] {
        return definition.interactableOffsets
    }

    func isBlocking(x: Int, y: Int) -> Bool {
        return interactableOffsets.contains { $0.x + origin.x == x && $0.y + origin.y == y }
    }

    func isInteractable(x: Int, y: Int) -> Bool {
        return isBlocking(x:x, y: y)
    }
}

struct MapTile {
    var floor: FloorKind
    var object: PlacedObject?
}
