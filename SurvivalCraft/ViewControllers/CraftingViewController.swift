import UIKit

class CraftingViewController: UIViewController {

    var inventory: Inventory!
    var availableRecipes: [CraftingRecipe] = []
    var onClose: (() -> Void)?

    private var stackView: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        setupStackView()
        loadRecipes()
        setupCloseButton()
    }

    private func setupStackView() {
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func loadRecipes() {
        for (index, recipe) in availableRecipes.enumerated() {
            let recipeView = createRecipeView(for: recipe, at: index)
            stackView.addArrangedSubview(recipeView)
        }
    }
    
    private func createRecipeView(for recipe: CraftingRecipe, at index: Int) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.distribution = .equalSpacing
        container.spacing = 16
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        // Left: Ingredients stack
        let leftStack = UIStackView()
        leftStack.axis = .horizontal
        leftStack.alignment = .center
        leftStack.spacing = 8

        for (ingredient, amount) in recipe.ingredients {
            leftStack.addArrangedSubview(createItemView(type: ingredient, amount: amount))
        }

        // Right: Arrow + Result
        let rightStack = UIStackView()
        rightStack.axis = .horizontal
        rightStack.alignment = .center
        rightStack.spacing = 8

        let arrowLabel = UILabel()
        arrowLabel.text = "→"
        arrowLabel.textColor = .white
        arrowLabel.font = UIFont.boldSystemFont(ofSize: 16)

        rightStack.addArrangedSubview(arrowLabel)
        rightStack.addArrangedSubview(createItemView(type: recipe.result, amount: recipe.amount))

        // Add both sides to the container
        container.addArrangedSubview(leftStack)
        container.addArrangedSubview(rightStack)

        // Make it tappable
        let tap = UITapGestureRecognizer(target: self, action: #selector(recipeTapped(_:)))
        container.addGestureRecognizer(tap)
        container.tag = index
        container.isUserInteractionEnabled = true

        // Style
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 2
        container.layer.borderColor = inventory.canCraft(recipe) ? UIColor.systemGreen.cgColor : UIColor.darkGray.cgColor
        container.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        return container
    }
    
    private func createItemView(type: InventoryItemType, amount: Int) -> UIView {
        let itemView = UIStackView()
        itemView.axis = .vertical
        itemView.alignment = .center
        itemView.spacing = 2

        let imageView = UIImageView(image: UIImage(named: type.rawValue))
        imageView.contentMode = .scaleAspectFit
        imageView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let label = UILabel()
        label.text = "×\(amount)"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white

        itemView.addArrangedSubview(imageView)
        itemView.addArrangedSubview(label)

        return itemView
    }

    @objc private func recipeTapped(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view,
              view.tag >= 0,
              view.tag < availableRecipes.count else { return }

        let recipe = availableRecipes[view.tag]

        if inventory.craft(recipe) {
            showConfirmation("Crafted \(GameItemRegistry.get(recipe.result).displayName)!")
            reloadCraftingUI()
        } else {
            showConfirmation("Not enough resources.")
        }
    }

    private func reloadCraftingUI() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        loadRecipes()
    }

    private func setupCloseButton() {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func showConfirmation(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Animate fade-in, pulse, then fade-out
        UIView.animate(withDuration: 0.2, animations: {
            label.alpha = 1.0
            label.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0.3, options: [], animations: {
                label.alpha = 0.0
                label.transform = .identity
            }) { _ in
                label.removeFromSuperview()
            }
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
        onClose?()
    }
}
