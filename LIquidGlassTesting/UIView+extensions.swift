//
//  UIView+extensions.swift
//  LIquidGlassTesting
//
//  Created by Léo Wiebusch on 11/12/25.
//

import UIKit

extension UIView {
    func backgroundImage(named: String) {
        let backgroundImage = UIImageView(frame: self.frame)
        backgroundImage.image = UIImage(named: named)
        backgroundImage.contentMode = .scaleAspectFill

        backgroundImage.center = self.center
        backgroundImage.autoresizingMask = [
            .flexibleLeftMargin,
            .flexibleRightMargin,
            .flexibleTopMargin,
            .flexibleBottomMargin
        ]

        self.insertSubview(backgroundImage, at: 0)
        self.sendSubviewToBack(backgroundImage)
    }
}
