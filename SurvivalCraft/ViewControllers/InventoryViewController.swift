import UIKit

class InventoryViewController: UIViewController {

    var inventory: Inventory!
    var onClose: (() -> Void)?
    private var selectedSlotIndex: Int?

    private var hotbarStack: UIStackView!
    private var inventoryGrid: UIStackView!
    private var allSlots: [InventorySlotView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.9)

        setupHotbar()
        setupInventoryGrid()
        setupCloseButton()
        setupCraftButton()
        updateInventoryDisplay()
        print("📦 Inventory has \(inventory.slots.count) slots!")
    }

    private func setupHotbar() {
        hotbarStack = UIStackView()
        hotbarStack.axis = .horizontal
        hotbarStack.spacing = 6
        hotbarStack.distribution = .fillEqually
        hotbarStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hotbarStack)

        for i in 0..<5 {
            let slot = createSlotView(index: i)
            hotbarStack.addArrangedSubview(slot)
            allSlots.append(slot)
        }

        NSLayoutConstraint.activate([
            hotbarStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            hotbarStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hotbarStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hotbarStack.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func setupInventoryGrid() {
        inventoryGrid = UIStackView()
        inventoryGrid.axis = .vertical
        inventoryGrid.spacing = 6
        inventoryGrid.distribution = .fillEqually
        inventoryGrid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inventoryGrid)

        for row in 0..<6 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 6
            rowStack.distribution = .fillEqually

            for col in 0..<5 {
                let index = 5 + row * 5 + col
                let slot = createSlotView(index: index)
                rowStack.addArrangedSubview(slot)
                allSlots.append(slot)
            }

            inventoryGrid.addArrangedSubview(rowStack)
        }

        NSLayoutConstraint.activate([
            inventoryGrid.topAnchor.constraint(equalTo: hotbarStack.bottomAnchor, constant: 16),
            inventoryGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inventoryGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            inventoryGrid.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: 200)
        ])
    }

    private func createSlotView(index: Int) -> InventorySlotView {
        let slot = InventorySlotView()
        slot.tag = index
        slot.translatesAutoresizingMaskIntoConstraints = false
        slot.widthAnchor.constraint(equalToConstant: 48).isActive = true
        slot.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(slotTapped(_:)))
        slot.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(slotLongPressed(_:)))
        slot.addGestureRecognizer(longPress)

        return slot
    }

    @objc private func slotTapped(_ gesture: UITapGestureRecognizer) {
        guard let slotView = gesture.view as? InventorySlotView else { return }
        let index = slotView.tag

        if selectedSlotIndex == nil {
            selectedSlotIndex = index
        } else {
            let source = selectedSlotIndex!
            inventory.moveItem(from: source, to: index)
            selectedSlotIndex = nil
        }

        updateInventoryDisplay()
    }

    @objc private func slotLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let slotView = gesture.view as? InventorySlotView else { return }

        let index = slotView.tag
        inventory.remove(at: index)
        selectedSlotIndex = nil
        updateInventoryDisplay()
    }

    func updateInventoryDisplay() {
        for (index, slotView) in allSlots.enumerated() {
            if index < inventory.slots.count {
                slotView.configure(with: inventory.slots[index])
            } else {
                slotView.configureEmpty()
            }

            let isSelected = index == selectedSlotIndex
            slotView.setSelected(isSelected)
        }
    }

    private func setupCloseButton() {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.tintColor = .white
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupCraftButton() {
        let button = UIButton(type: .system)
        button.setTitle("Craft", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.tintColor = .white
        button.addTarget(self, action: #selector(openCraftingScreen), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func openCraftingScreen() {
        let craftingVC = CraftingViewController()
        craftingVC.inventory = self.inventory
        craftingVC.availableRecipes = GameItemRegistry.allCraftable
        craftingVC.modalPresentationStyle = .overFullScreen
        craftingVC.onClose = { [weak self] in
            self?.updateInventoryDisplay()
        }
        present(craftingVC, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
        onClose?()
    }
}
