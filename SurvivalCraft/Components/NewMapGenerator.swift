import Foundation
import GameplayKit

struct MapParameters {
    var seed: UInt64 = 678
    var waterThreshold: Float = 0.3
    var beachRadius: Int = 2
    var objectPercentages: [ObjectKind: Double] = [
        .tree: 0.007,
        .tree2: 0.005,
        .rock: 0.005,
        .rock_large: 0.001,
        .berry: 0.007
    ]
}

class MapGenerator {
    let width: Int
    let height: Int
    let params: MapParameters
    let rng: GKMersenneTwisterRandomSource
    let noiseMap: GKNoiseMap

    init(width: Int, height: Int, parameters: MapParameters = MapParameters()) {
        self.width = width
        self.height = height
        self.params = parameters
        self.rng = GKMersenneTwisterRandomSource(seed: parameters.seed)

        let noiseSource = GKPerlinNoiseSource(
            frequency: 1.5,
            octaveCount: 6,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: Int32(parameters.seed)
        )
        let noise = GKNoise(noiseSource)
        self.noiseMap = GKNoiseMap(
            noise,
            size: vector_double2(1.0, 1.0),
            origin: vector_double2(0.0, 0.0),
            sampleCount: vector_int2(Int32(width), Int32(height)),
            seamless: true
        )
    }

    func generate() -> GameMap {
        let map = GameMap(width: width, height: height)
        generateFloors(into: map)
        expandBeaches(into: map, radius: params.beachRadius)
        placeObjects(into: map)
        return map
    }

    private func generateFloors(into map: GameMap) {
        for y in 0..<height {
            for x in 0..<width {
                let value = noiseMap.value(at: vector_int2(Int32(x), Int32(y)))
                let kind: FloorKind = value < params.waterThreshold ? .water : .land
                map.setFloor(x: x, y: y, kind: kind)
            }
        }
    }

    private func expandBeaches(into map: GameMap, radius: Int) {
        for y in 0..<height {
            for x in 0..<width {
                guard map.getFloor(x: x, y: y) == .land else { continue }
                if isNearWater(x: x, y: y, radius: radius, in: map) {
                    map.setFloor(x: x, y: y, kind: .beach)
                }
            }
        }
    }

    private func isNearWater(x: Int, y: Int, radius: Int, in map: GameMap) -> Bool {
        for dy in -radius...radius {
            for dx in -radius...radius {
                let nx = x + dx
                let ny = y + dy
                if nx >= 0 && ny >= 0 && nx < width && ny < height {
                    if map.getFloor(x: nx, y: ny) == .water {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func placeObjects(into map: GameMap) {
        for (kind, percentage) in params.objectPercentages {
            let definition = ObjectDatabase.all[kind]!
            let total = width * height
            let targetCount = Int(Double(total) * percentage)

            var attempts = 0
            var placed = 0
            let maxAttempts = targetCount * 10

            while placed < targetCount && attempts < maxAttempts {
                let x = rng.nextInt(upperBound: width)
                let y = rng.nextInt(upperBound: height)
                if map.canPlaceObject(definition, atX: x, y: y) {
                    map.placeObject(definition, atX: x, y: y)
                    placed += 1
                }
                attempts += 1
            }
        }
    }
}
