enum FloorKind: String, CaseIterable {
    case land, water, beach
}

struct FloorDefinition {
    let kind: FloorKind
    let isWalkable: Bool
    let textureWeights: [String: Int] // textureName: weight
}

struct FloorDatabase {
    static let all: [FloorKind: FloorDefinition] = [
        .land: FloorDefinition(
            kind: .land,
            isWalkable: true,
            textureWeights: [
                "land1": 1,
                "land2": 1,
                "land3": 4,
                "land4": 1,
                "land5": 1,
            ]
        ),
        .beach: FloorDefinition(
            kind: .beach,
            isWalkable: true,
            textureWeights: [
                "beach1": 1,
                "beach2": 1,
                "beach3": 4,
                "beach4": 1,
            ]
        ),
        .water: FloorDefinition(
            kind: .water,
            isWalkable: false,
            textureWeights: [
                "water": 1
            ]
        )
    ]
}
