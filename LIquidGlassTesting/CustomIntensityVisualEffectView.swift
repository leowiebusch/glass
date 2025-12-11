//
//  CustomIntensityVisualEffectView.swift
//  LIquidGlassTesting
//
//  Created by Léo Wiebusch on 11/12/25.
//

import UIKit

class CustomIntensityVisualEffectView: UIVisualEffectView {
    // Private property animator
    private var animator: UIViewPropertyAnimator

    /// Create a visual effect view with a given effect and its intensity.
    ///
    /// - Parameters:
    ///   - effect: The visual effect, e.g., UIBlurEffect(style: .dark)
    ///   - intensity: Custom intensity from 0.0 (no effect) to 1.0 (full effect)
    init(effect: UIVisualEffect, intensity: CGFloat) {
        
        animator = UIViewPropertyAnimator(duration: 0.0001, curve: .linear)
        
        super.init(effect: nil)
        setupAnimator(effect: effect, intensity: intensity)
        
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupAnimator(effect: UIVisualEffect, intensity: CGFloat) {
        animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [unowned self] in
            self.effect = effect
        }
        // Set the desired intensity by adjusting the fractionComplete
        animator.fractionComplete = intensity
    }
}
