import UIKit

/// Frosted-glass panel without per-cell blur (performance-friendly on iPad mini 2).
final class GlassPanelView: UIView {

    private let tintView = UIView()
    private let borderView = UIView()

    var panelTint: UIColor = DashboardTheme.glassPurple {
        didSet { tintView.backgroundColor = panelTint }
    }

    var cornerRadius: CGFloat = 16 {
        didSet {
            layer.cornerRadius = cornerRadius
            tintView.layer.cornerRadius = cornerRadius
            borderView.layer.cornerRadius = cornerRadius
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DashboardTheme.glassFill
        layer.cornerRadius = cornerRadius
        clipsToBounds = false

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        tintView.backgroundColor = panelTint
        tintView.layer.cornerRadius = cornerRadius
        tintView.clipsToBounds = true

        borderView.backgroundColor = .clear
        borderView.layer.cornerRadius = cornerRadius
        borderView.layer.borderWidth = 1
        borderView.layer.borderColor = DashboardTheme.glassBorder.cgColor
        borderView.isUserInteractionEnabled = false

        [tintView, borderView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: topAnchor),
            tintView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: bottomAnchor),

            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }

    func setGlowActive(_ active: Bool) {
        if active {
            layer.shadowColor = DashboardTheme.onGlow.cgColor
            layer.shadowOpacity = 0.35
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.28
        }
    }
}
