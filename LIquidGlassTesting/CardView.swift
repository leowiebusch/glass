//
//  CardView.swift
//  LIquidGlassTesting
//
//  Created by Léo Wiebusch on 11/12/25.
//
import UIKit

class CardView: GlassView {
    
    override init() {
        super.init()
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
    
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([ heightAnchor.constraint(greaterThanOrEqualToConstant: 200) ])
    }
}
