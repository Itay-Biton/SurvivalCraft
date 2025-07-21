import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    @IBOutlet weak var invantoryView: UIButton!
    @IBOutlet weak var hotbarStackView: UIStackView!
    @IBOutlet weak var craftingView: UIButton!
    @IBOutlet weak var pauseView: UIButton!
    
    var selectedHotbarIndex: Int? = nil
    var hotbarSlots: [InventorySlotView] = []
    var player: PlayerNode?
    var gameScene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGameScene()
        setupHotbar()
    }
    
    func toggleUI(visible: Bool) {
        invantoryView.isHidden = !visible
        hotbarStackView.isHidden = !visible
        craftingView.isHidden = !visible
        pauseView.isHidden = !visible
    }

    func setupGameScene() {
        guard let skView = self.view as? SKView else { return }

        let sceneSize = UIScreen.main.bounds.size // ensure correct size
        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .aspectFill
        scene.viewController = self
        
        skView.presentScene(scene)
        
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        
        self.gameScene = scene
    }
    
    func connectHotbarToPlayer(_ player: PlayerNode) {
        self.player = player
        
        setupHotbar() // create UI slots
        
        player.inventory.onChange = { [weak self] in
            guard let self = self else { return }
            self.updateHotbar(with: player.inventory)
        }
        
        updateHotbar(with: player.inventory)
    }

    private var traitChangeRegistration: UITraitChangeRegistration?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Register for color scheme changes (iOS 17+)
        // This closure correctly captures 'self' (the ViewController) and 'view' (the SKView)
        traitChangeRegistration = view.registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { [weak self] (view: UIView, previousTrait: UITraitCollection) in
            // Inside this closure, 'view' is the SKView, and 'view.traitCollection' is valid.
            // 'self' is the GameViewController.
            print("GameViewController: Trait change detected for SKView. New style: \(view.traitCollection.userInterfaceStyle == .dark ? "Dark" : "Light")")
            self?.gameScene?.reloadTileMapForAppearanceChange()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Unregister to prevent leaks
        // Setting it to nil effectively unregisters
        traitChangeRegistration = nil
    }

    func setupHotbar() {
        hotbarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        hotbarSlots.removeAll()

        for index in 0..<5 {
            let slotView = InventorySlotView()
            slotView.tag = index
            slotView.translatesAutoresizingMaskIntoConstraints = false
            slotView.widthAnchor.constraint(equalToConstant: 48).isActive = true
            slotView.heightAnchor.constraint(equalToConstant: 48).isActive = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(hotbarSlotTapped(_:)))
            slotView.addGestureRecognizer(tap)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(hotbarSlotLongPressed(_:)))
            longPress.minimumPressDuration = 0.5
            slotView.addGestureRecognizer(longPress)

            slotView.isUserInteractionEnabled = true

            hotbarStackView.addArrangedSubview(slotView)
            hotbarSlots.append(slotView)
        }
        // ✅ Refresh AFTER creating slots
        if let inventory = player?.inventory {
            updateHotbar(with: inventory)
        }
    }

    func updateHotbar(with inventory: Inventory) {
        guard hotbarSlots.count >= 5 else {
            print("⚠️ Hotbar not fully initialized yet!")
            return
        }
        let firstFiveSlots = inventory.slots.prefix(5)
        for (index, slot) in firstFiveSlots.enumerated() {
            let isSelected = index == selectedHotbarIndex
            hotbarSlots[index].configure(with: slot, isSelected: isSelected)
        }
    }

    @objc func hotbarSlotTapped(_ gesture: UITapGestureRecognizer) {
        guard let scene = gameScene, !scene.isPausedCompletely else { return }
        
        guard let view = gesture.view else { return }
        let index = view.tag

        selectedHotbarIndex = (index == selectedHotbarIndex) ? nil : index
        updateHotbar(with: player?.inventory ?? Inventory())
    }
    
    @objc func hotbarSlotLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard let scene = gameScene, !scene.isPausedCompletely else { return }
        
        guard gesture.state == .began, let view = gesture.view else { return }
        let index = view.tag

        guard let slot = player?.inventory.slots[safe: index],
              let item = slot.type,
              item == .berry // You can later generalize this
        else {
            return
        }

        if player?.eat(item: item) == true {
            updateHotbar(with: player?.inventory ?? Inventory())
        }
    }

    @IBAction func openInventory(_ sender: Any) {
        guard let scene = gameScene, !scene.isPausedCompletely else { return }
        
        let invVC = InventoryViewController()
        invVC.inventory = player?.inventory
        invVC.modalPresentationStyle = .overFullScreen
        invVC.onClose = { [weak self] in
            self?.updateHotbar(with: self?.player?.inventory ?? Inventory())
        }
        present(invVC, animated: true)
    }

    @IBAction func openCrafting(_ sender: Any) {
        guard let scene = gameScene, !scene.isPausedCompletely else { return }
        
        let craftingVC = CraftingViewController()
        craftingVC.inventory = player?.inventory
        craftingVC.availableRecipes = GameItemRegistry.allCraftable
        craftingVC.modalPresentationStyle = .overFullScreen
        present(craftingVC, animated: true)
    }
    
    @IBAction func togglePause(_ sender: Any) {
        gameScene?.togglePause()
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
