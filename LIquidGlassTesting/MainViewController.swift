//
//  ViewController.swift
//  LIquidGlassTesting
//
//  Created by Léo Wiebusch on 08/12/25.
//

import UIKit

class MainViewController: UIViewController {

    let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.bounces = true
        view.bouncesVertically = true
        return view
    }()
    
    let stackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .fill
        view.spacing = 16
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }
    
    func setupUI() {
        view.backgroundImage(named: "hanoi.jpg")
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
    
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12),
            stackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: 20),
            stackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor, constant: 20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        let card1 = CardView()
        let glass = BorderRefractionView()
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.config = .init(
            cornerRadius: 24,
            borderWidth: 14,
            displacementScale: 12,
            centerStyle: .passthrough,
            continuousUpdate: false,
            useSimplifiedMode: true  // Modo otimizado e rápido
        )

        card1.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.centerXAnchor.constraint(equalTo: card1.centerXAnchor),
            glass.centerYAnchor.constraint(equalTo: card1.centerYAnchor)
        ])

        glass.refresh()

        stackView.addArrangedSubview(card1)
        
        // Card 2: GlassView com efeitos de reflexo e brilho nos cantos
        let card2 = GlassView()
//        card2.style.edgeReflectionEnabled = true
//        card2.style.edgeReflectionWidth = 50
//        card2.style.edgeReflectionIntensity = 0.35
//        card2.style.cornerGlowEnabled = true
//        card2.style.cornerGlowRadius = 60
//        card2.style.cornerGlowIntensity = 0.3
        stackView.addArrangedSubview(card2)
        
        // Card 3: CardView simples
        
        
        stackView.addArrangedSubview(CardView())
        stackView.addArrangedSubview(CardView())
        stackView.addArrangedSubview(CardView())
        stackView.addArrangedSubview(CardView())
        stackView.addArrangedSubview(CardView())
        stackView.addArrangedSubview(CardView())
    }
}

#Preview {
    UINavigationController(rootViewController: MainViewController())
}
