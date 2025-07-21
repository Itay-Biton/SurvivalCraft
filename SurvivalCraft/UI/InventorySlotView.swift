import UIKit

class InventorySlotView: UIView {
    let iconImageView = UIImageView()
    let countLabel = UILabel()
    let durabilityBar = UIProgressView(progressViewStyle: .bar)
    let borderView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(red: 0.25, green: 0.3, blue: 0.2, alpha: 1.0) // Minecraft-like greenish

        layer.borderWidth = 2
        layer.borderColor = UIColor.black.cgColor
        layer.cornerRadius = 4
        clipsToBounds = true

        iconImageView.contentMode = .scaleAspectFit
        addSubview(iconImageView)

        countLabel.font = UIFont.boldSystemFont(ofSize: 12)
        countLabel.textColor = .white
        countLabel.textAlignment = .right
        addSubview(countLabel)

        durabilityBar.trackTintColor = .darkGray
        durabilityBar.progressTintColor = .green
        addSubview(durabilityBar)

        // Layout constraints
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        durabilityBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            iconImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            countLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            durabilityBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            durabilityBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            durabilityBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            durabilityBar.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    func configure(with item: InventorySlot?, isSelected: Bool) {
        if let type = item?.type {
            iconImageView.image = UIImage(named: type.rawValue)
            countLabel.text = item!.count > 1 ? "\(item!.count)" : ""
            durabilityBar.isHidden = GameItemRegistry.get(type).defaultDurability == nil
            if let maxDurability = GameItemRegistry.get(type).defaultDurability {
                let currentDurability = item!.durability ?? maxDurability
                durabilityBar.progress = Float(currentDurability) / Float(maxDurability)
            }
        } else {
            iconImageView.image = nil
            countLabel.text = ""
            durabilityBar.isHidden = true
        }

        layer.borderColor = isSelected ? UIColor.white.cgColor : UIColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with slot: InventorySlot) {
        configure(with: slot, isSelected: false)
    }

    func configureEmpty() {
        iconImageView.image = nil
        countLabel.text = ""
        durabilityBar.isHidden = true
        layer.borderColor = UIColor.black.cgColor
    }
    
    func setSelected(_ selected: Bool) {
        layer.borderColor = selected ? UIColor.white.cgColor : UIColor.black.cgColor
        layer.borderWidth = selected ? 3 : 2
    }
}
