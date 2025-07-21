import SpriteKit
import GameplayKit

class GameScene: SKScene {
    public var player: PlayerNode!

    private var cameraNode: SKCameraNode!
    private var overlayNode: SKNode!
    private var tileMapNode: SKTileMapNode?
    private var tileSize = CGSize(width: 32, height: 32)
    private var pauseOverlay: SKNode?
    private var gameMap: GameMap!
    private var pathfinder: Pathfinder!
    private var mapGenerator: MapGenerator!
    private var currentPath: [vector_int2] = []

    var objectVisuals: [vector_int2: SKNode] = [:]
    var statsHUD: StatsHUD!

    weak var viewController: GameViewController?
    
    private var isGamePaused: Bool = false
    var worldLoaded = false

    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.lastUpdateTime = 0
        let parameters = MapParameters(seed: 4, waterThreshold: 0.1, beachRadius: 2)
        mapGenerator = MapGenerator(width: 100, height: 100, parameters: parameters)
        
        setupCamera()
        
        // Hide UIKit UI so SK menu is clickable
        viewController?.toggleUI(visible: false)
    
        showSaveSelectionMenu()
        
        // ✅ Listen for app lifecycle events for autosave/pause
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        isGamePaused = true
        self.isPaused = true
    }

    @objc private func appDidEnterBackground() {
        isGamePaused = true
        self.isPaused = true
    }

    @objc private func appDidBecomeActive() {
        self.isPaused = false
        isGamePaused = false
        // ✅ Reset lastUpdateTime to avoid big delta
        lastUpdateTime = 0
    }
    
    func togglePause() {
        isGamePaused.toggle()
        
        if (isGamePaused) {
            showPauseMenu()
        }
        else {
            hidePauseMenu()
        }
    }
    
    var isPausedCompletely: Bool {
        return isGamePaused
    }
    
    private func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        
        cameraNode.setScale(1.0) // start normal
        let zoomAction = SKAction.scale(to: 0.6, duration: 0.6)
        zoomAction.timingMode = .easeOut
        cameraNode.run(zoomAction)

        overlayNode = SKNode()
        addChild(overlayNode)
    }

    func renderBaseTilesIncrementally(completion: @escaping () -> Void) {
        tileMapNode?.removeFromParent()
        tileMapNode = nil
        
        guard let traitCollection = view?.traitCollection else { return }
        
        // ✅ Preload textures & SKTileGroups once
        let allTextureNames = Set(FloorDatabase.all.values.flatMap { $0.textureWeights.keys })
        var tileGroupDict: [String: SKTileGroup] = [:]
        
        for textureName in allTextureNames {
            let image = UIImage(named: textureName, in: nil, compatibleWith: traitCollection)
            let texture = image.map { SKTexture(image: $0) } ?? SKTexture(imageNamed: textureName)
            let tileDef = SKTileDefinition(texture: texture)
            let group = SKTileGroup(tileDefinition: tileDef)
            group.name = textureName
            tileGroupDict[textureName] = group
        }
        
        let tileSet = SKTileSet(tileGroups: Array(tileGroupDict.values))
        
        // ✅ Create empty tileMap first
        let tileMap = SKTileMapNode(
            tileSet: tileSet,
            columns: gameMap.width,
            rows: gameMap.height,
            tileSize: tileSize
        )
        tileMap.anchorPoint = .zero
        tileMap.position = .zero
        tileMap.zPosition = 0
        addChild(tileMap)
        tileMapNode = tileMap
        
        // ✅ Prepare work list
        var tilesToRender: [(x: Int, y: Int, texture: String)] = []
        
        for y in 0..<gameMap.height {
            for x in 0..<gameMap.width {
                if let floorKind = gameMap.getFloor(x: x, y: y),
                   let floorDef = FloorDatabase.all[floorKind] {
                    let weightedTextures = floorDef.textureWeights.flatMap { texture, weight in
                        Array(repeating: texture, count: weight)
                    }
                    if let chosen = weightedTextures.randomElement() {
                        tilesToRender.append((x, y, chosen))
                    }
                }
            }
        }
        
        // ✅ Render in batches
        var index = 0
        let batchSize = 300
        
        func renderBatch() {
            let endIndex = min(index + batchSize, tilesToRender.count)
            for i in index..<endIndex {
                let tile = tilesToRender[i]
                let row = gameMap.height - 1 - tile.y
                if let group = tileGroupDict[tile.texture] {
                    tileMap.setTileGroup(group, forColumn: tile.x, row: row)
                }
            }
            index = endIndex
            
            if index < tilesToRender.count {
                // ✅ Yield to next frame
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: renderBatch)
            } else {
                print("✅ Finished rendering tiles incrementally!")
                completion()
            }
        }
        
        renderBatch()
    }

    func renderObjectVisualsIncrementally(completion: @escaping () -> Void) {
        overlayNode.removeAllChildren()
        objectVisuals.removeAll()
        
        var objectsToRender: [(x: Int, y: Int, def: ObjectDefinition)] = []
        
        for y in 0..<gameMap.height {
            for x in 0..<gameMap.width {
                if let obj = gameMap.getObject(atX: x, y: y),
                   obj.origin == (x, y) {
                    objectsToRender.append((x, y, obj.definition))
                }
            }
        }
        
        var index = 0
        let batchSize = 100
        
        func renderBatch() {
            let endIndex = min(index + batchSize, objectsToRender.count)
            for i in index..<endIndex {
                let obj = objectsToRender[i]
                
                let texture = SKTexture(imageNamed: obj.def.textureName)
                let sprite = SKSpriteNode(texture: texture)
                
                let px = CGFloat(obj.x) * tileSize.width
                let py = CGFloat(gameMap.height - 1 - obj.y) * tileSize.height
                
                sprite.name = "object_\(obj.x)_\(obj.y)"
                sprite.anchorPoint = obj.def.anchor
                sprite.position = CGPoint(x: px, y: py)
                sprite.zPosition = 3
                
                overlayNode.addChild(sprite)
                let key = vector_int2(Int32(obj.x), Int32(obj.y))
                objectVisuals[key] = sprite
            }
            index = endIndex
            
            if index < objectsToRender.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: renderBatch)
            } else {
                print("✅ Finished rendering objects incrementally!")
                completion()
            }
        }
        
        renderBatch()
    }

    private func findFirstWalkableTilePosition() -> CGPoint? {
        for y in gameMap.height/2..<gameMap.height {
            for x in gameMap.width/2..<gameMap.width {
                if gameMap.isWalkable(x: x, y: y) {
                    return CGPoint(
                        x: CGFloat(x) * tileSize.width + tileSize.width / 2,
                        y: CGFloat(gameMap.height - 1 - y) * tileSize.height + tileSize.height / 2
                    )
                }
            }
        }
        return nil
    }

    private var queuedInteraction: CGPoint? = nil

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // ✅ If we are in save selection menu (world not loaded), only handle menu taps
        if !worldLoaded {
            handleStartupMenuTap(at: location)
            return
        }

        // ✅ Pause menu handling
        if isPausedCompletely {
            let tappedNodes = nodes(at: location)
            for node in tappedNodes {
                guard let name = node.name else { continue }

                if name == "resumeButton" {
                    togglePause()
                    return

                } else if name.hasPrefix("load_") {
                    let worldName = name.replacingOccurrences(of: "load_", with: "")
                    
                    // ✅ Show loading overlay before closing pause menu
                    let _ = showLoadingOverlay()
                    
                    // ✅ Hide pause menu immediately
                    hidePauseMenu()
                    
                    // ✅ Load save in background
                    DispatchQueue.global(qos: .userInitiated).async {
                        guard let save = SaveSystem.shared.loadGame(worldName: worldName) else {
                            print("⚠️ Failed to load \(worldName)")
                            DispatchQueue.main.async { self.hideLoadingOverlay() }
                            return
                        }
                        
                        // ✅ Smooth incremental world rebuild on main
                        DispatchQueue.main.async {
                            self.loadWorldSmoothlyFromSave(save, worldName: worldName)
                        }
                    }
                    return
                } else if name.hasPrefix("save_") {
                    let worldName = name.replacingOccurrences(of: "save_", with: "")
                    saveCurrentWorld(named: worldName)
                    return

                } else if name.hasPrefix("delete_") {
                    let worldName = name.replacingOccurrences(of: "delete_", with: "")
                    SaveSystem.shared.deleteGame(worldName: worldName)
                    reloadPauseMenu()
                    return

                } else if name == "createNewSave" {
                    let newName = "world_\(Int(Date().timeIntervalSince1970))"
                    saveCurrentWorld(named: newName)
                    reloadPauseMenu()
                    return
                }
            }
            return
        }

        // ✅ Ignore UI taps (like hotbar)
        if let view = self.view {
            let uiPoint = touch.location(in: view)
            if let hotbar = viewController?.hotbarStackView,
               hotbar.frame.contains(uiPoint) {
                return
            }
        }

        // Check if player is near any animal
        for animal in animals {
            let dist = hypot(animal.position.x - location.x, animal.position.y - location.y)
            if dist < 20 { // tap close enough
                let playerDist = hypot(animal.position.x - player.position.x, animal.position.y - player.position.y)
                if playerDist < 80 { // player must also be near
                    animal.hitByPlayer(damage: 10)
                    return
                }
            }
        }
    
        // ✅ Try interact first
        if player.interact(
            at: location,
            tileSize: tileSize,
            map: gameMap,
            pathfinder: pathfinder,
            scene: self,
            viewController: viewController
        ) {
            return
        }

        // ✅ If too far, queue interaction
        let tile = pointToGrid(location)
        if let object = gameMap.getObject(atX: Int(tile.x), y: Int(tile.y)),
           object.isInteractable(x: Int(tile.x), y: Int(tile.y)) {

            if let targetTile = pathfinder.findNearestWalkableAround(x: Int(tile.x), y: Int(tile.y)) {
                let playerTile = pointToGrid(player.position)
                currentPath = pathfinder.findPath(from: playerTile, to: targetTile)
                queuedInteraction = location
                return
            }
        }

        // ✅ Otherwise handle movement normally
        let gridTarget = pointToGrid(location)
        let playerGrid = pointToGrid(player.position)
        currentPath = pathfinder.findPath(from: playerGrid, to: gridTarget)
    }
    
    func loadWorldSmoothlyFromSave(_ save: GameSaveData, worldName: String) {
        // Clear old stuff
        tileMapNode?.removeFromParent()
        overlayNode.removeAllChildren()
        objectVisuals.removeAll()
        player?.removeFromParent()
        
        // Create new empty map
        gameMap = GameMap(width: 100, height: 100)
        pathfinder = Pathfinder(map: gameMap)
        
        // Restore floors in data
        for tile in save.mapTiles {
            if let kind = FloorKind(rawValue: tile.kind) {
                gameMap.setFloor(x: tile.x, y: tile.y, kind: kind)
            }
        }
        
        // Incremental tiles
        renderBaseTilesIncrementally {
            // Restore object data
            for obj in save.objects {
                if let def = ObjectDatabase.getDefinition(for: obj.kind) {
                    self.gameMap.placeObject(def, atX: obj.x, y: obj.y)
                }
            }
            
            // Incremental objects
            self.renderObjectVisualsIncrementally {
                // Restore player
                self.player = PlayerNode(position: .zero)
                self.addChild(self.player)
                
                self.player.position = CGPoint(x: save.playerPositionX,
                                               y: save.playerPositionY)
                self.player.stats.health = save.health
                self.player.stats.hunger = save.hunger
                
                // HUD
                self.statsHUD = StatsHUD()
                self.statsHUD.position = CGPoint(x: -self.frame.width / 2 + 70,
                                                 y: self.frame.height / 2 - 72)
                self.cameraNode.addChild(self.statsHUD)
                
                // Inventory
                self.player.inventory.slots = save.inventorySlots.map { codable in
                    if let raw = codable.item,
                       let type = InventoryItemType(rawValue: raw) {
                        return InventorySlot(type: type,
                                             count: codable.count,
                                             durability: codable.durability)
                    } else {
                        return .empty
                    }
                }
                
                if let vc = self.viewController {
                    vc.selectedHotbarIndex = save.selectedHotbarIndex
                    vc.updateHotbar(with: self.player.inventory)
                }
                
                self.cameraNode.position = self.player.position
                
                self.isGamePaused = false
                self.worldLoaded = true
                self.viewController?.toggleUI(visible: true)
                
                print("✅ Loaded world smoothly from pause menu: \(worldName)")
                self.hideLoadingOverlay()
            }
        }
    }
    
    private func handleStartupMenuTap(at location: CGPoint) {
        let tappedNodes = nodes(at: location)
        for node in tappedNodes {
            guard let name = node.name else { continue }
            if name.hasPrefix("startup_load_") {
                let world = name.replacingOccurrences(of: "startup_load_", with: "")
                loadSelectedWorld(world)
                return
            } else if name.hasPrefix("startup_delete_") {
                let world = name.replacingOccurrences(of: "startup_delete_", with: "")
                SaveSystem.shared.deleteGame(worldName: world)
                pauseOverlay?.removeFromParent()
                pauseOverlay = nil
                showSaveSelectionMenu()
                return
            } else if name == "startup_createNew" {
                createNewWorld()
                return
            }
        }
    }
    
    private func pointToGrid(_ point: CGPoint) -> vector_int2 {
        guard let gm = gameMap else { return vector_int2(0,0) }
        let col = Int(point.x / tileSize.width)
        let row = gm.height - 1 - Int(point.y / tileSize.height)
        return vector_int2(Int32(col), Int32(row))
    }

    private var lastUpdateTime: TimeInterval = 0

    func isPositionWalkable(_ point: CGPoint) -> Bool {
        let grid = pointToGrid(point)
        let gx = Int(grid.x)
        let gy = Int(grid.y)
        // Also ensure within map bounds
        guard gx >= 0, gy >= 0, gx < gameMap.width, gy < gameMap.height else {
            return false
        }
        return gameMap.isWalkable(x: gx, y: gy)
    }
    
    private func updateAnimalSpawning(dt: TimeInterval) {
        // ✅ Only spawn if under cap
        if animals.count >= maxAnimals { return }

        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnTimer = spawnInterval
            spawnSingleAnimal()
        }
    }

    private func spawnSingleAnimal() {
        guard let gm = gameMap else { return }
        
        // Try to find a random valid spawn tile
        var spawnPosition: CGPoint? = nil
        for _ in 0..<20 { // try 20 attempts
            let randX = Int.random(in: 0..<gm.width)
            let randY = Int.random(in: 0..<gm.height)
            if gm.isWalkable(x: randX, y: randY) {
                spawnPosition = CGPoint(
                    x: CGFloat(randX) * tileSize.width + tileSize.width/2,
                    y: CGFloat(gm.height - 1 - randY) * tileSize.height + tileSize.height/2
                )
                break
            }
        }
        
        guard let pos = spawnPosition else {
            print("⚠️ No valid spawn tile found for new animal")
            return
        }
        
        // Pick a random kind
        let kind = AnimalKind.allCases.randomElement()!
        let newAnimal = AnimalNode(kind: kind)
        newAnimal.position = pos
        newAnimal.gameScene = self
        
        addChild(newAnimal)
        animals.append(newAnimal)
        
        print("🦌 Spawned new \(kind.rawValue) at \(pos). Total animals: \(animals.count)")
    }
    
    func removeAnimal(_ animal: AnimalNode) {
        if let index = animals.firstIndex(where: { $0 === animal }) {
            animals.remove(at: index)
            print("🗑️ Removed \(animal.kind.rawValue) from animals array. Total: \(animals.count)")
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard worldLoaded else { return }

        if isGamePaused {
            player.setAnimationPaused(true)
            lastUpdateTime = currentTime
            return
        } else {
            player.setAnimationPaused(false)
        }

        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        for animal in animals {
            animal.update(deltaTime: dt)
        }
        // ✅ Natural animal spawning
        updateAnimalSpawning(dt: dt)
        
        // ✅ Update player stats
        player.stats.update(deltaTime: dt)
        statsHUD.update(with: player.stats)

        let wasWalking = player.isWalking
        let oldDirection = player.direction

        guard !currentPath.isEmpty else {
            player.isWalking = false
            if wasWalking { player.updateAnimationIfNeeded() }

            // ✅ If we reached destination and queuedInteraction exists → try interact now
            if let queued = queuedInteraction {
                print("🎯 Reached target, trying queued interaction")
                if player.interact(
                    at: queued,
                    tileSize: tileSize,
                    map: gameMap,
                    pathfinder: pathfinder,
                    scene: self,
                    viewController: viewController
                ) {
                    print("✅ Queued interaction succeeded!")
                }
                queuedInteraction = nil
            }

            return
        }

        // ✅ Handle movement
        let next = currentPath[0]
        let nextPos = CGPoint(
            x: CGFloat(next.x) * tileSize.width + tileSize.width / 2,
            y: CGFloat(gameMap.height - 1 - Int(next.y)) * tileSize.height + tileSize.height / 2
        )

        let dx = nextPos.x - player.position.x
        let dy = nextPos.y - player.position.y

        if abs(dx) > 0.001 {
            player.direction = dx > 0 ? .right : .left
        }

        let distance = hypot(dx, dy)
        let step = player.speed * CGFloat(dt)

        if distance < step {
            player.position = nextPos
            currentPath.remove(at: 0)
            player.isWalking = !currentPath.isEmpty
        } else {
            let vx = dx / distance * step
            let vy = dy / distance * step
            player.position.x += vx
            player.position.y += vy
            player.isWalking = true
        }

        if player.isWalking != wasWalking || player.direction != oldDirection {
            player.updateAnimationIfNeeded()
        }

        cameraNode.position = player.position
    }

    func reloadTileMapForAppearanceChange() {
        guard worldLoaded else { return }
        
        tileMapNode?.removeFromParent()
        overlayNode.removeAllChildren()
        objectVisuals.removeAll()
        
        let _ = showLoadingOverlay()
        
        renderBaseTilesIncrementally {
            self.renderObjectVisualsIncrementally {
                self.hideLoadingOverlay()
            }
        }
    }
    
    func showPauseMenu() {
        guard pauseOverlay == nil else { return }

        isGamePaused = true
        
        // Hide UIKit UI so SK menu is clickable
        viewController?.toggleUI(visible: false)
        let overlay = SKNode()
        overlay.zPosition = 9999

        let screenSize = view?.bounds.size ?? CGSize(width: 800, height: 600)

        // Dim background
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.5), size: screenSize)
        dim.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dim.position = .zero
        dim.name = "dim"
        overlay.addChild(dim)

        // Title
        let title = SKLabelNode(text: "Paused")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 42
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: screenSize.height/2 - 120)
        overlay.addChild(title)

        // Resume Button
        let resumeButton = SKLabelNode(text: "Resume")
        resumeButton.fontName = "AvenirNext-Bold"
        resumeButton.fontSize = 36
        resumeButton.fontColor = .white
        resumeButton.position = CGPoint(x: 0, y: screenSize.height/2 - 200)
        resumeButton.name = "resumeButton"
        overlay.addChild(resumeButton)

        // --- SAVES LIST ---
        let saves = SaveSystem.shared.listSaves()
        var yOffset = screenSize.height/2 - 300

        if saves.isEmpty {
            let emptyLabel = SKLabelNode(text: "No saved worlds")
            emptyLabel.fontName = "AvenirNext-Regular"
            emptyLabel.fontSize = 24
            emptyLabel.fontColor = .white
            emptyLabel.position = CGPoint(x: 0, y: yOffset)
            overlay.addChild(emptyLabel)
            yOffset -= 70
        } else {
            for world in saves {
                // World name label
                let saveLabel = SKLabelNode(text: "World: \(world)")
                saveLabel.fontName = "AvenirNext-Regular"
                saveLabel.fontSize = 28
                saveLabel.fontColor = .white
                saveLabel.position = CGPoint(x: 0, y: yOffset)
                saveLabel.horizontalAlignmentMode = .center
                overlay.addChild(saveLabel)

                // Buttons directly BELOW the save label
                let buttonsYOffset = yOffset - 35

                let loadBtn = SKLabelNode(text: "Load")
                loadBtn.fontName = "AvenirNext-Bold"
                loadBtn.fontSize = 24
                loadBtn.fontColor = .green
                loadBtn.position = CGPoint(x: -100, y: buttonsYOffset)
                loadBtn.name = "load_\(world)"
                overlay.addChild(loadBtn)

                let saveBtn = SKLabelNode(text: "Overwrite")
                saveBtn.fontName = "AvenirNext-Bold"
                saveBtn.fontSize = 24
                saveBtn.fontColor = .yellow
                saveBtn.position = CGPoint(x: 0, y: buttonsYOffset)
                saveBtn.name = "save_\(world)"
                overlay.addChild(saveBtn)

                let delBtn = SKLabelNode(text: "Delete")
                delBtn.fontName = "AvenirNext-Bold"
                delBtn.fontSize = 24
                delBtn.fontColor = .red
                delBtn.position = CGPoint(x: 100, y: buttonsYOffset)
                delBtn.name = "delete_\(world)"
                overlay.addChild(delBtn)

                // Add spacing for next save entry
                yOffset -= 90
            }
        }

        // Create New Save Button
        let newSaveBtn = SKLabelNode(text: "+ Create New Save")
        newSaveBtn.fontName = "AvenirNext-Bold"
        newSaveBtn.fontSize = 30
        newSaveBtn.fontColor = .cyan
        newSaveBtn.position = CGPoint(x: 0, y: yOffset - 40)
        newSaveBtn.name = "createNewSave"
        overlay.addChild(newSaveBtn)

        pauseOverlay = overlay
        cameraNode.addChild(overlay)
    }
    
    func reloadPauseMenu() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        showPauseMenu()
    }
    
    func hidePauseMenu() {
        isGamePaused = false
        
        // Restore UIKit UI
        viewController?.toggleUI(visible: true)
        
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
    }
    
    func showSaveSelectionMenu() {
        pauseOverlay?.removeFromParent()
        
        // Hide UIKit UI so SK menu is clickable
        viewController?.toggleUI(visible: false)
        let overlay = SKNode()
        overlay.zPosition = 99999
        
        // ✅ Always use scene size (correct after presentScene)
        let screenSize = self.size
        let halfHeight = screenSize.height / 2
        
        // Dim background fills entire screen
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: screenSize)
        dim.position = .zero  // center
        dim.name = "dim"
        overlay.addChild(dim)
        
        // Title
        let title = SKLabelNode(text: "Select World")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 42
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: halfHeight - 100)
        overlay.addChild(title)
        
        let saves = SaveSystem.shared.listSaves()
        var yOffset = halfHeight - 200
        
        if saves.isEmpty {
            let emptyLabel = SKLabelNode(text: "No saved worlds yet")
            emptyLabel.fontName = "AvenirNext-Regular"
            emptyLabel.fontSize = 26
            emptyLabel.fontColor = .white
            emptyLabel.position = CGPoint(x: 0, y: yOffset)
            overlay.addChild(emptyLabel)
            yOffset -= 70
        } else {
            for world in saves {
                let saveLabel = SKLabelNode(text: "World: \(world)")
                saveLabel.fontName = "AvenirNext-Regular"
                saveLabel.fontSize = 30
                saveLabel.fontColor = .white
                saveLabel.position = CGPoint(x: 0, y: yOffset)
                overlay.addChild(saveLabel)
                
                let btnY = yOffset - 40
                
                let loadBtn = SKLabelNode(text: "Load")
                loadBtn.fontName = "AvenirNext-Bold"
                loadBtn.fontSize = 24
                loadBtn.fontColor = .green
                loadBtn.position = CGPoint(x: -100, y: btnY)
                loadBtn.name = "startup_load_\(world)"
                overlay.addChild(loadBtn)
                
                let delBtn = SKLabelNode(text: "Delete")
                delBtn.fontName = "AvenirNext-Bold"
                delBtn.fontSize = 24
                delBtn.fontColor = .red
                delBtn.position = CGPoint(x: 100, y: btnY)
                delBtn.name = "startup_delete_\(world)"
                overlay.addChild(delBtn)
                
                yOffset -= 90
            }
        }
        
        // Create new world button
        let newSaveBtn = SKLabelNode(text: "+ Create New World")
        newSaveBtn.fontName = "AvenirNext-Bold"
        newSaveBtn.fontSize = 30
        newSaveBtn.fontColor = .cyan
        newSaveBtn.position = CGPoint(x: 0, y: yOffset - 50)
        newSaveBtn.name = "startup_createNew"
        overlay.addChild(newSaveBtn)
        
        pauseOverlay = overlay
        cameraNode.addChild(overlay)
        
        print("✅ Save selection menu added with \(saves.count) saves")
    }
    
    func loadSelectedWorld(_ world: String) {
        // Remove any menus
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        
        let _ = showLoadingOverlay()
        
        // ✅ 1. Load saveData on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            guard let saveData = SaveSystem.shared.loadGame(worldName: world) else {
                print("⚠️ No save data for \(world)")
                DispatchQueue.main.async { self.hideLoadingOverlay() }
                return
            }
            
            DispatchQueue.main.async {
                // ✅ 2. Prepare empty map
                self.gameMap = GameMap(width: 100, height: 100)
                self.pathfinder = Pathfinder(map: self.gameMap)
                
                // ✅ 3. Deserialize floor data into gameMap (just data, no visuals yet)
                for tile in saveData.mapTiles {
                    if let kind = FloorKind(rawValue: tile.kind) {
                        self.gameMap.setFloor(x: tile.x, y: tile.y, kind: kind)
                    }
                }
                
                // ✅ 4. Incrementally render base tiles first
                self.renderBaseTilesIncrementally {
                    
                    // ✅ 5. Deserialize & render objects incrementally
                    for obj in saveData.objects {
                        if let def = ObjectDatabase.getDefinition(for: obj.kind) {
                            self.gameMap.placeObject(def, atX: obj.x, y: obj.y)
                        }
                    }
                    
                    self.renderObjectVisualsIncrementally {
                        
                        // ✅ 6. Now restore player
                        self.player = PlayerNode(position: .zero)
                        self.addChild(self.player)
                        
                        self.player.position = CGPoint(x: saveData.playerPositionX,
                                                       y: saveData.playerPositionY)
                        self.player.stats.health = saveData.health
                        self.player.stats.hunger = saveData.hunger
                        
                        self.statsHUD = StatsHUD()
                        self.statsHUD.position = CGPoint(x: -self.frame.width / 2 + 70,
                                                         y: self.frame.height / 2 - 72)
                        self.cameraNode.addChild(self.statsHUD)
                        
                        // ✅ Restore inventory
                        self.player.inventory.slots = saveData.inventorySlots.map { codable in
                            if let raw = codable.item,
                               let type = InventoryItemType(rawValue: raw) {
                                return InventorySlot(type: type,
                                                     count: codable.count,
                                                     durability: codable.durability)
                            } else {
                                return .empty
                            }
                        }
                        
                        // After restoring player...
                        for animalData in saveData.animals {
                            if let kind = AnimalKind(rawValue: animalData.kind) {
                                let animal = AnimalNode(kind: kind)
                                animal.position = CGPoint(x: animalData.posX, y: animalData.posY)
                                animal.gameScene = self
                                self.addChild(animal)
                                self.animals.append(animal)
                            }
                        }

                        if let vc = self.viewController {
                            vc.selectedHotbarIndex = saveData.selectedHotbarIndex
                            vc.updateHotbar(with: self.player.inventory)
                        }
                        
                        self.cameraNode.position = self.player.position
                        
                        self.isGamePaused = false
                        self.worldLoaded = true
                        self.viewController?.toggleUI(visible: true)
                        
                        print("✅ Loaded selected world: \(world) smoothly!")
                        
                        // ✅ Hide spinner
                        self.hideLoadingOverlay()
                    }
                }
            }
        }
    }

    func createNewWorld() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
        
        let _ = showLoadingOverlay()
        
        // ✅ Generate map OFF main thread
        DispatchQueue.global(qos: .userInitiated).async {
            let newMap = self.mapGenerator.generate()
            
            DispatchQueue.main.async {
                self.gameMap = newMap
                self.pathfinder = Pathfinder(map: newMap)
                
                // ✅ STEP 1: Incremental tile rendering
                self.renderBaseTilesIncrementally {
                    
                    // ✅ STEP 2: Incremental object rendering
                    self.renderObjectVisualsIncrementally {
                        
                        // ✅ STEP 3: Spawn animals (fast, so no batching needed)
                        self.spawnInitialAnimals()
                        
                        // ✅ STEP 4: Place player
                        if let spawnPos = self.findFirstWalkableTilePosition() {
                            self.player = PlayerNode(position: spawnPos)
                            self.addChild(self.player)
                            self.cameraNode.position = spawnPos
                            
                            self.statsHUD = StatsHUD()
                            self.statsHUD.position = CGPoint(x: -self.frame.width / 2 + 70,
                                                             y: self.frame.height / 2 - 72)
                            self.cameraNode.addChild(self.statsHUD)
                        }
                        
                        self.viewController?.connectHotbarToPlayer(self.player)
                        
                        // Save world initially
                        self.saveCurrentWorld(named: "world_\(Int(Date().timeIntervalSince1970))")
                        
                        self.isGamePaused = false
                        self.worldLoaded = true
                        self.viewController?.toggleUI(visible: true)
                        
                        print("✅ Created a new world smoothly!")
                        
                        // ✅ Finally hide loading screen
                        self.hideLoadingOverlay()
                    }
                }
            }
        }
    }
    
    var animals: [AnimalNode] = []
    // Animal spawning control
    let maxAnimals = 20              // hard population limit
    let spawnInterval: TimeInterval = 3.0  // spawn 1 animal every 3s
    private var spawnTimer: TimeInterval = 0.0
    
    func spawnInitialAnimals(count: Int = 15) {
        guard gameMap != nil else { return }
        
        for _ in 0..<count {
            let kind = AnimalKind.allCases.randomElement()!
            
            // Find a random walkable tile
            var position: CGPoint? = nil
            for _ in 0..<20 { // try up to 20 times
                let randX = Int.random(in: 0..<gameMap.width)
                let randY = Int.random(in: 0..<gameMap.height)
                if gameMap.isWalkable(x: randX, y: randY) {
                    position = CGPoint(
                        x: CGFloat(randX) * tileSize.width + tileSize.width/2,
                        y: CGFloat(gameMap.height - 1 - randY) * tileSize.height + tileSize.height/2
                    )
                    break
                }
            }
            
            if let pos = position {
                let animal = AnimalNode(kind: kind)
                animal.position = pos
                animal.gameScene = self
                addChild(animal)
                animals.append(animal)
            }
        }
    }
}

extension GameScene {
    
    func makeSaveData(worldName: String) -> GameSaveData {
        let slotSaves = player.inventory.slots.map { slot in
            InventorySlotCodable(
                item: slot.type?.rawValue,
                count: slot.count,
                durability: slot.durability
            )
        }
        
        let animalSaves = animals.map { animal -> AnimalSaveData in
            return AnimalSaveData(
                kind: animal.kind.rawValue,
                posX: animal.position.x,
                posY: animal.position.y
            )
        }
        
        return GameSaveData(
            version: 3,
            worldName: worldName,
            timestamp: Date(),
            playerPositionX: player.position.x,
            playerPositionY: player.position.y,
            health: player.stats.health,
            hunger: player.stats.hunger,
            inventorySlots: slotSaves,
            selectedHotbarIndex: viewController?.selectedHotbarIndex ?? 0,
            mapTiles: serializeMap(),
            objects: serializeObjects(),
            animals: animalSaves // ✅ include animals
        )
    }
    
    func applySaveData(_ save: GameSaveData) {
        guard gameMap != nil else { return }
        guard player != nil else { return }

        // ✅ Clear old visuals
        overlayNode.removeAllChildren()
        objectVisuals.removeAll()
        
        // ✅ Restore floors & objects
        deserializeMap(save.mapTiles)
        deserializeObjects(save.objects)
        pathfinder.rebuildFromMap(gameMap)
        
        // ✅ Restore player
        player.position = CGPoint(x: save.playerPositionX, y: save.playerPositionY)
        player.stats.health = save.health
        player.stats.hunger = save.hunger
        
        // ✅ Restore inventory
        player.inventory.slots = save.inventorySlots.map { codable in
            if let raw = codable.item, let type = InventoryItemType(rawValue: raw) {
                return InventorySlot(type: type, count: codable.count, durability: codable.durability)
            } else {
                return .empty
            }
        }
        
        if let vc = viewController {
            vc.selectedHotbarIndex = save.selectedHotbarIndex
            vc.updateHotbar(with: player.inventory)
        }
        
        // ✅ Remove old animals
        for animal in animals {
            animal.removeFromParent()
        }
        animals.removeAll()
        
        // ✅ Restore animals
        for animalData in save.animals {
            if let kind = AnimalKind(rawValue: animalData.kind) {
                let animal = AnimalNode(kind: kind)
                animal.position = CGPoint(x: animalData.posX, y: animalData.posY)
                animal.gameScene = self
                addChild(animal)
                animals.append(animal)
            }
        }
        
        // ✅ Center camera
        cameraNode.position = player.position
    }
    
    func saveCurrentWorld(named worldName: String) {
        let saveData = makeSaveData(worldName: worldName)
        SaveSystem.shared.saveGame(worldName: worldName, saveData: saveData)
    }
    
    func loadWorld(named worldName: String) {
        guard let save = SaveSystem.shared.loadGame(worldName: worldName) else { return }
        applySaveData(save)
    }
    
    func serializeMap() -> [FloorTileSave] {
        var result: [FloorTileSave] = []
        for y in 0..<gameMap.height {
            for x in 0..<gameMap.width {
                if let floor = gameMap.getFloor(x: x, y: y) {
                    result.append(FloorTileSave(x: x, y: y, kind: floor.rawValue))
                }
            }
        }
        return result
    }

    func serializeObjects() -> [ObjectSaveData] {
        var result: [ObjectSaveData] = []
        for y in 0..<gameMap.height {
            for x in 0..<gameMap.width {
                if let obj = gameMap.getObject(atX: x, y: y),
                   obj.origin == (x, y) {
                    result.append(ObjectSaveData(x: x, y: y, kind: obj.kind.rawValue))
                }
            }
        }
        return result
    }
    
    func deserializeMap(_ tiles: [FloorTileSave]) {
        // ✅ Apply data immediately (cheap, no visuals yet)
        for tile in tiles {
            if let kind = FloorKind(rawValue: tile.kind) {
                gameMap.setFloor(x: tile.x, y: tile.y, kind: kind)
            }
        }
        
        // ✅ Don't render all at once → call incremental
        renderBaseTilesIncrementally {
            print("✅ Finished smooth base tile rendering after deserialize")
        }
    }

    func deserializeObjects(_ objects: [ObjectSaveData]) {
        for obj in objects {
            if let def = ObjectDatabase.getDefinition(for: obj.kind) {
                
                // ✅ Place it into the map grid (marks occupied offsets)
                gameMap.placeObject(def, atX: obj.x, y: obj.y)
                
                // ✅ Then create the visual
                let texture = SKTexture(imageNamed: def.textureName)
                let sprite = SKSpriteNode(texture: texture)

                let px = CGFloat(obj.x) * tileSize.width
                let py = CGFloat(gameMap.height - 1 - obj.y) * tileSize.height

                sprite.anchorPoint = def.anchor
                sprite.position = CGPoint(x: px, y: py)
                sprite.zPosition = 3

                overlayNode.addChild(sprite)
                let key = vector_int2(Int32(obj.x), Int32(obj.y))
                objectVisuals[key] = sprite
            }
        }
    }
}

extension GameScene {
    func showLoadingOverlay() -> SKNode {
        // Remove any existing one first
        cameraNode.childNode(withName: "loadingOverlay")?.removeFromParent()
        
        let overlay = SKNode()
        overlay.name = "loadingOverlay"
        overlay.zPosition = 999_999
        
        let screenSize = self.size
        
        // Dim background
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: screenSize)
        dim.position = .zero
        dim.zPosition = 0
        overlay.addChild(dim)
        
        // "Loading..." label
        let loadingLabel = SKLabelNode(text: "Loading...")
        loadingLabel.fontName = "AvenirNext-Bold"
        loadingLabel.fontSize = 40
        loadingLabel.fontColor = .white
        loadingLabel.position = CGPoint(x: 0, y: 40)
        loadingLabel.zPosition = 1
        overlay.addChild(loadingLabel)
        
        // ✅ Nicer spinner arc
        let spinner = makeSpinner(radius: 30, lineWidth: 6)
        spinner.position = CGPoint(x: 0, y: -40)
        overlay.addChild(spinner)
        
        // Start transparent for fade-in
        overlay.alpha = 0.0
        cameraNode.addChild(overlay)
        
        // Smooth fade-in
        overlay.run(SKAction.fadeIn(withDuration: 0.3))
        
        return overlay
    }
    
    func hideLoadingOverlay() {
        if let overlay = cameraNode.childNode(withName: "loadingOverlay") {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            overlay.run(SKAction.sequence([fadeOut, remove]))
        }
    }
    
    func makeSpinner(radius: CGFloat = 30, lineWidth: CGFloat = 4) -> SKShapeNode {
        let circlePath = UIBezierPath(
            arcCenter: .zero,
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 1.5, // 270° arc
            clockwise: true
        )
        
        let shape = SKShapeNode(path: circlePath.cgPath)
        shape.strokeColor = .white
        shape.lineWidth = lineWidth
        shape.lineCap = .round
        shape.fillColor = .clear
        shape.zPosition = 1
        
        // Rotate forever
        let rotate = SKAction.rotate(byAngle: -CGFloat.pi * 2, duration: 1.2)
        shape.run(SKAction.repeatForever(rotate))
        
        return shape
    }
}
