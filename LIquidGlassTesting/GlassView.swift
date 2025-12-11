//
//  GlassView.swift
//  LIquidGlassTesting
//
//  Created by Léo Wiebusch on 08/12/25.
//

import UIKit


///  Dicas de qualidade visual
///  Direção do gradiente da borda (startPoint/endPoint) controla onde a luz "bate".
///  Topo-esquerda → bottom-direita costuma dar um reflexo bonito.
///  cornerCurve = .continuous melhora o visual dos cantos com materiais.
///  Highlight especular curto e com alpha baixo (0.25–0.45) evita exagero.
///  Inner shadow muito sutil (opacity ~0.1–0.15) ajuda no "volume" sem escurecer demais.
///
///  Performance
///   - Evite recalcular paths em cada frame; aqui fazemos em layoutSubviews.
///   - Desabilitamos animações implícitas das CALayer para evitar hitches.
///   - UIVisualEffectView com .system*Material* é mais eficiente e com integração nativa do iOS 15.
///   - Se tiver scroll veloz atrás, teste em devices antigos: reduzir innerShadowRadius e highlight pode ajudar.
///
protocol GlassTokens {
    var cornerRadius: CGFloat { get }
    var borderWidth: CGFloat { get }
    var borderColors: [UIColor] { get }
    var borderLocations: [NSNumber] { get }
    var borderStartPoint: CGPoint { get }
    var borderEndPoint: CGPoint { get }
    var highlightColors: [UIColor] { get }
    var highlightStartPoint: CGPoint { get }
    var highlightEndPoint: CGPoint { get }
    var innerShadowOpacity: Float { get }
    var innerShadowRadius: CGFloat { get }
    var blurStyle: UIBlurEffect.Style { get }
}

extension GlassView.Style {
    init(tokens: GlassTokens) {
        self.cornerRadius = tokens.cornerRadius
        self.borderWidth = tokens.borderWidth
        self.borderColors = tokens.borderColors
        self.borderLocations = tokens.borderLocations
        self.borderStartPoint = tokens.borderStartPoint
        self.borderEndPoint   = tokens.borderEndPoint
        self.highlightColors = tokens.highlightColors
        self.highlightStartPoint = tokens.highlightStartPoint
        self.highlightEndPoint   = tokens.highlightEndPoint
        self.innerShadowOpacity = tokens.innerShadowOpacity
        self.innerShadowRadius  = tokens.innerShadowRadius
        self.blurStyle = tokens.blurStyle
    }
}

/// UIView com estilo "glass": blur de material, borda com gradiente e highlight especular.
class GlassView: UIView {

    // MARK: - Camadas
    private let blurView: UIVisualEffectView
    private let borderGradient = CAGradientLayer()
    private let borderMask = CAShapeLayer()
    private let specularHighlight = CAGradientLayer()
    private let innerShadowLayer = CAShapeLayer()
    
    // Novas camadas para efeito de reflexo nas extremidades
    private let edgeReflectionLayer = CAGradientLayer()
    private let cornerGlowLayers: [CAGradientLayer] = [
        CAGradientLayer(), CAGradientLayer(), CAGradientLayer(), CAGradientLayer()
    ]

    // MARK: - Configuráveis (pense em tokens de DS)
    struct Style {
        var cornerRadius: CGFloat = 16
        var borderWidth: CGFloat = 1.0
        var borderColors: [UIColor] = [
            UIColor.white.withAlphaComponent(0.55), // brilho (top/left)
            UIColor.white.withAlphaComponent(0.10), // meio
            UIColor.black.withAlphaComponent(0.18)  // sombra (bottom/right)
        ]
        /// Posição do gradiente da borda: 0..1
        var borderLocations: [NSNumber] = [0.0, 0.5, 1.0]
        /// Direção do gradiente (ajuste para orientar o brilho)
        var borderStartPoint: CGPoint = CGPoint(x: 0.0, y: 0.0)  // topo-esquerda
        var borderEndPoint: CGPoint   = CGPoint(x: 1.0, y: 1.0)  // bottom-direita

        /// Highlight especular (faixa curta de brilho)
        var highlightColors: [UIColor] = [
            UIColor.white.withAlphaComponent(0.35),
            UIColor.white.withAlphaComponent(0.0)
        ]
        var highlightStartPoint: CGPoint = CGPoint(x: 0.0, y: 0.0)
        var highlightEndPoint: CGPoint   = CGPoint(x: 0.6, y: 0.2) // inclinado

        /// Intensidade da sombra interna (0 = sem)
        var innerShadowOpacity: Float = 0.15
        var innerShadowRadius: CGFloat = 4
        var innerShadowColor: UIColor = UIColor.black
        var contentInset: UIEdgeInsets = .zero

        /// Estilo do material (iOS 13+). Para iOS 15, pode usar systemThinMaterial*.
        var blurStyle: UIBlurEffect.Style = .systemThinMaterialLight
        
        /// Configurações de reflexo nas extremidades
        var edgeReflectionEnabled: Bool = true
        var edgeReflectionWidth: CGFloat = 40 // largura da faixa de reflexo
        var edgeReflectionIntensity: CGFloat = 0.3
        
        /// Configurações de brilho nos cantos (efeito lupa simplificado)
        var cornerGlowEnabled: Bool = false
        var cornerGlowRadius: CGFloat = 60
        var cornerGlowIntensity: CGFloat = 0.25
    }

    var style: Style {
        didSet { applyStyle() }
    }
    
    init() {
        let blurEffect = UIBlurEffect(style: .light)
        blurView = CustomIntensityVisualEffectView(effect: blurEffect, intensity: 0.05)
        
        style = .init(
            cornerRadius: 20,
            borderWidth: 1.0,
            borderColors: [
                UIColor.white.withAlphaComponent(0.6),
//                UIColor.black.withAlphaComponent(0.20),
                UIColor.white.withAlphaComponent(0.05),
                UIColor.white.withAlphaComponent(0.12)
            ],
            borderLocations: [0.0, 0.55, 1.0],
            borderStartPoint: CGPoint(x: 0.0, y: 0.0),
            borderEndPoint:   CGPoint(x: 1.0, y: 1.0),
            highlightColors: [
                UIColor.white.withAlphaComponent(0.40),
                UIColor.white.withAlphaComponent(0.0)
            ],
            highlightStartPoint: CGPoint(x: 0.0, y: 0.0),
            highlightEndPoint:   CGPoint(x: 0.6, y: 0.2),
            innerShadowOpacity: 0.12,
            innerShadowRadius: 6,
            blurStyle: .systemThinMaterialLight
        )
        super.init(frame: .zero)
        isOpaque = false

        setupBlur()
        setupBorderGradient()
        setupSpecularHighlight()
        setupInnerShadow()
        setupEdgeReflection()
        setupCornerGlow()
        applyStyle()
    }

    required init?(coder: NSCoder) {
        self.style = Style()
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: style.blurStyle))
        super.init(coder: coder)
        isOpaque = false
        backgroundColor = UIColor.clear

        setupBlur()
        setupBorderGradient()
        setupSpecularHighlight()
        setupInnerShadow()
        setupEdgeReflection()
        setupCornerGlow()
        applyStyle()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }
    
    // MARK: - Setup
    private func setupBlur() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: style.contentInset.left),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -style.contentInset.right),
            blurView.topAnchor.constraint(equalTo: topAnchor, constant: style.contentInset.top),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -style.contentInset.bottom)
        ])
        blurView.clipsToBounds = true
    }

    private func setupBorderGradient() {
        layer.addSublayer(borderGradient)
        borderGradient.mask = borderMask
        borderGradient.masksToBounds = false
        // Desabilita animações implícitas para evitar "piscadas"
        borderGradient.actions = ["bounds": NSNull(), "position": NSNull(), "path": NSNull()]
        borderMask.actions = ["path": NSNull()]
    }

    private func setupSpecularHighlight() {
        layer.addSublayer(specularHighlight)
        // Contribui com o brilho especular sobre o conteúdo
        specularHighlight.actions = ["bounds": NSNull(), "position": NSNull()]
    }

    private func setupInnerShadow() {
        layer.addSublayer(innerShadowLayer)
        innerShadowLayer.fillRule = .evenOdd
        innerShadowLayer.actions = ["path": NSNull(), "shadowPath": NSNull()]
    }
    
    private func setupEdgeReflection() {
        // Adiciona reflexo nas extremidades (topo, cantos)
        layer.addSublayer(edgeReflectionLayer)
        edgeReflectionLayer.type = .radial
        edgeReflectionLayer.actions = ["bounds": NSNull(), "position": NSNull()]
    }
    
    private func setupCornerGlow() {
        // Adiciona gradientes radiais nos cantos para simular reflexo/refração
        for glowLayer in cornerGlowLayers {
            glowLayer.type = .radial
            glowLayer.actions = ["bounds": NSNull(), "position": NSNull()]
            layer.insertSublayer(glowLayer, at: 0)
        }
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        // Corner em todas as camadas que precisam
        blurView.layer.cornerRadius = style.cornerRadius
        blurView.layer.cornerCurve = .continuous

        let bounds = self.bounds

        // Borda com gradiente ocupa toda a view (máscara delimita o traçado)
        borderGradient.frame = bounds
        borderMask.frame = bounds

        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: style.borderWidth/2, dy: style.borderWidth/2),
                                cornerRadius: style.cornerRadius)
        borderMask.path = path.cgPath
        borderMask.lineWidth = style.borderWidth
        borderMask.fillColor = UIColor.clear.cgColor
        borderMask.strokeColor = UIColor.black.cgColor // cor não importa, máscara usa o traço

        // Highlight especular como uma faixa suave
        specularHighlight.frame = bounds
        specularHighlight.cornerRadius = style.cornerRadius

        // Sombra interna
        innerShadowLayer.frame = bounds
        let outer = UIBezierPath(roundedRect: bounds, cornerRadius: style.cornerRadius)
        let inner = UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: max(style.cornerRadius - 1, 0))
        let combined = UIBezierPath()
        combined.append(outer)
        combined.append(inner)
        innerShadowLayer.path = combined.cgPath
        innerShadowLayer.shadowPath = outer.cgPath
        innerShadowLayer.shadowColor = style.innerShadowColor.cgColor
        innerShadowLayer.shadowOpacity = style.innerShadowOpacity
        innerShadowLayer.shadowRadius = style.innerShadowRadius
        innerShadowLayer.shadowOffset = CGSize(width: 0, height: 2)
        innerShadowLayer.fillColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        // Configurar reflexo nas extremidades
        if style.edgeReflectionEnabled {
            updateEdgeReflection()
        }
        
        // Configurar brilho nos cantos
        if style.cornerGlowEnabled {
            updateCornerGlow()
        }

        applyStyle() // garante gradientes/points após relayout
    }
    
    private func updateEdgeReflection() {
        let bounds = self.bounds
        edgeReflectionLayer.frame = bounds
        
        // Gradiente radial do topo para criar reflexo nas extremidades
        let topCenter = CGPoint(x: 0.5, y: 0)
        edgeReflectionLayer.startPoint = topCenter
        edgeReflectionLayer.endPoint = CGPoint(x: 0.5, y: style.edgeReflectionWidth / bounds.height)
        
        // Cores: branco transparente no topo, fade para transparente
        let reflectionColor = UIColor.white.withAlphaComponent(style.edgeReflectionIntensity)
        edgeReflectionLayer.colors = [
            reflectionColor.cgColor,
            reflectionColor.withAlphaComponent(style.edgeReflectionIntensity * 0.3).cgColor,
            UIColor.clear.cgColor
        ]
        edgeReflectionLayer.locations = [0.0, 0.5, 1.0]
        
        // Adicionar máscaras para os cantos também
        let maskLayer = CAShapeLayer()
        let maskPath = UIBezierPath(roundedRect: bounds, cornerRadius: style.cornerRadius)
        maskLayer.path = maskPath.cgPath
        edgeReflectionLayer.mask = maskLayer
    }
    
    private func updateCornerGlow() {
        let bounds = self.bounds
        let radius = style.cornerGlowRadius
        let intensity = style.cornerGlowIntensity
        
        // Posições dos cantos
        let corners: [CGPoint] = [
            CGPoint(x: style.cornerRadius * 0.5, y: style.cornerRadius * 0.5), // top-left
            CGPoint(x: bounds.width - style.cornerRadius * 0.5, y: style.cornerRadius * 0.5), // top-right
            CGPoint(x: style.cornerRadius * 0.5, y: bounds.height - style.cornerRadius * 0.5), // bottom-left
            CGPoint(x: bounds.width - style.cornerRadius * 0.5, y: bounds.height - style.cornerRadius * 0.5) // bottom-right
        ]
        
        for (index, glowLayer) in cornerGlowLayers.enumerated() {
            let corner = corners[index]
            
            // Frame ao redor do canto
            glowLayer.frame = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            // Gradiente radial: branco no centro, transparente nas bordas
            let glowColor = UIColor.white.withAlphaComponent(intensity)
            glowLayer.colors = [
                glowColor.cgColor,
                glowColor.withAlphaComponent(intensity * 0.5).cgColor,
                UIColor.clear.cgColor
            ]
            glowLayer.locations = [0.0, 0.5, 1.0]
            glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        }
    }

    // MARK: - Estilo
    private func applyStyle() {
        // Borda – gradiente (usamos a máscara para traçar somente a borda)
        borderGradient.colors = style.borderColors.map { $0.cgColor }
        borderGradient.locations = style.borderLocations
        borderGradient.startPoint = style.borderStartPoint
        borderGradient.endPoint   = style.borderEndPoint

        // Highlight especular
        specularHighlight.colors = style.highlightColors.map { $0.cgColor }
        specularHighlight.startPoint = style.highlightStartPoint
        specularHighlight.endPoint   = style.highlightEndPoint

        // Ajustes finos
        layer.cornerRadius = style.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = false
        
        // Controlar visibilidade dos efeitos
        edgeReflectionLayer.isHidden = !style.edgeReflectionEnabled
        cornerGlowLayers.forEach { $0.isHidden = !style.cornerGlowEnabled }
    }
}

#Preview {
    UINavigationController(rootViewController: MainViewController())
}

