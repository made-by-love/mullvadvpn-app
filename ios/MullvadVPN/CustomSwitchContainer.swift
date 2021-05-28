//
//  CustomSwitchContainer.swift
//  MullvadVPN
//
//  Created by pronebird on 20/05/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit

class CustomSwitchContainer: UIView {
    static let borderEdgeInsets = UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)

    private let borderShape: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.borderColor = UIColor.Switch.borderColor.cgColor
        shapeLayer.borderWidth = 2
        if #available(iOS 13.0, *) {
            shapeLayer.cornerCurve = .continuous
        }
        return shapeLayer
    }()

    let control = CustomSwitch()

    override var intrinsicContentSize: CGSize {
        return controlSize()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return controlSize()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(control)
        layer.addSublayer(borderShape)

        control.sizeToFit()
        sizeToFit()

        borderShape.cornerRadius = self.bounds.height * 0.5
        borderShape.frame = self.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        control.frame.origin = CGPoint(x: Self.borderEdgeInsets.left, y: Self.borderEdgeInsets.top)
    }

    // MARK: - Private

    private func controlSize() -> CGSize {
        var size = control.bounds.size
        size.width += Self.borderEdgeInsets.left + Self.borderEdgeInsets.right
        size.height += Self.borderEdgeInsets.top + Self.borderEdgeInsets.bottom
        return size
    }

}