//
//  BorderRefractionView.swift
//  LIquidGlassTesting
//
//  Created by Léo Wiebusch on 11/12/25.
//

import UIKit
import CoreImage

/// Refração apenas nas bordas, deformando o conteúdo debaixo da view.
/// Miolo pode ser "pass-through" (sem alteração) ou com blur.
final class BorderRefractionView: UIView {

    enum CenterStyle {
        case passthrough                 // mostra o backdrop original no centro
        case blur(radius: CGFloat)       // aplica gaussian blur no centro
    }

    struct Config {
        var cornerRadius: CGFloat = 20
        var borderWidth: CGFloat = 12            // faixa de borda que sofre refração
        var displacementScale: CGFloat = 12      // intensidade (px) da refração
        var centerStyle: CenterStyle = .blur(radius: 12)
        var continuousUpdate: Bool = false       // atualiza em tempo real (custa CPU/GPU)
        var preferredFPS: Int = 30
        var clipsToCorner: Bool = true
        var useSimplifiedMode: Bool = true       // usa modo simplificado mais rápido
    }

    var config = Config() {
        didSet { applyConfigAndRender() }
    }

    private let imageView = UIImageView()
    private let ciContext = CIContext(options: nil)
    private var displayLink: CADisplayLink?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isOpaque = false
        backgroundColor = .clear

        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        imageView.contentMode = .scaleToFill

        applyConfigAndRender()
    }

    private func applyConfigAndRender() {
        layer.cornerRadius = config.cornerRadius
        layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = config.cornerRadius
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = config.clipsToCorner
        setupDisplayLinkIfNeeded()
        render()
    }

    // MARK: - Layout
    override func didMoveToWindow() {
        super.didMoveToWindow()
        setupDisplayLinkIfNeeded()
        render()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        render()
    }

    // MARK: - DisplayLink
    private func setupDisplayLinkIfNeeded() {
        displayLink?.invalidate()
        displayLink = nil
        guard config.continuousUpdate else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = config.preferredFPS
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        render()
    }

    // MARK: - Public
    /// Atualiza manualmente (útil quando continuousUpdate=false)
    func refresh() {
        render()
    }

    // MARK: - Render pipeline
    private func render() {
        guard let window = self.window,
              bounds.width > 0, bounds.height > 0 else { return }

        // Modo simplificado: apenas usa um gradiente para simular o efeito
        if config.useSimplifiedMode {
            renderSimplified()
            return
        }

        // Evita capturar a própria imagem
        let wasHidden = imageView.isHidden
        imageView.isHidden = true
        defer { imageView.isHidden = wasHidden }

        // Renderiza em background thread para não travar a UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let rectInWindow = self.convert(self.bounds, to: window)
            let format = UIGraphicsImageRendererFormat()
            format.scale = min(window.screen.scale, 2.0) // Limita scale para performance
            format.opaque = false

            let renderer = UIGraphicsImageRenderer(size: self.bounds.size, format: format)
            let snapshot = renderer.image { ctx in
                ctx.cgContext.translateBy(x: -rectInWindow.origin.x, y: -rectInWindow.origin.y)
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }
            
            guard let ciBase = CIImage(image: snapshot) else { return }
            let extent = ciBase.extent

            // Aplica blur no centro se necessário
            var processedImage = ciBase
            if case .blur(let r) = self.config.centerStyle {
                if let blur = CIFilter(name: "CIGaussianBlur") {
                    blur.setValue(ciBase, forKey: kCIInputImageKey)
                    blur.setValue(r, forKey: kCIInputRadiusKey)
                    if let out = blur.outputImage?.cropped(to: extent) {
                        processedImage = out
                    }
                }
            }

            // Renderiza o resultado final
            if let cg = self.ciContext.createCGImage(processedImage, from: processedImage.extent) {
                DispatchQueue.main.async {
                    self.imageView.image = UIImage(cgImage: cg)
                }
            }
        }
    }
    
    // Modo simplificado - muito mais rápido
    private func renderSimplified() {
        // Cria um efeito visual simples com CAGradientLayer para simular refração
        imageView.image = nil
        
        // Remove layers antigos
        layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        // Adiciona gradientes nas bordas para simular o efeito de refração
        let borderGradient = CAGradientLayer()
        borderGradient.frame = bounds
        borderGradient.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor,
            UIColor.clear.cgColor
        ]
        borderGradient.locations = [0.0, 0.5, 1.0]
        borderGradient.startPoint = CGPoint(x: 0, y: 0)
        borderGradient.endPoint = CGPoint(x: 1, y: 1)
        
        // Máscara para mostrar apenas as bordas
        let maskLayer = CAShapeLayer()
        let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: config.cornerRadius)
        let innerRect = bounds.insetBy(dx: config.borderWidth, dy: config.borderWidth)
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: max(config.cornerRadius - config.borderWidth, 0))
        
        outerPath.append(innerPath)
        maskLayer.path = outerPath.cgPath
        maskLayer.fillRule = .evenOdd
        
        borderGradient.mask = maskLayer
        layer.insertSublayer(borderGradient, at: 0)
    }

    // MARK: - Displacement map (somente bordas têm desvio; resto neutro)
    private func createEdgeDisplacementMap(extent: CGRect,
                                           borderWidth: CGFloat,
                                           cornerRadius: CGFloat) -> CIImage {
        let w = extent.width
        let h = extent.height
        let e = borderWidth
        // O mapa deve ser neutro (0.5) fora das bordas; pequeno desvio dentro delas:
        let delta: CGFloat = 0.06  // 0.04~0.08 sutil e bonito

        let neutral = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)).cropped(to: extent)
        var base = neutral

        func linearGradient(point0: CGPoint, point1: CGPoint, color0: CIColor, color1: CIColor) -> CIImage {
            let g = CIFilter(name: "CILinearGradient")!
            g.setValue(CIVector(x: point0.x, y: point0.y), forKey: "inputPoint0")
            g.setValue(color0, forKey: "inputColor0")
            g.setValue(CIVector(x: point1.x, y: point1.y), forKey: "inputPoint1")
            g.setValue(color1, forKey: "inputColor1")
            return g.outputImage!.cropped(to: extent)
        }

        func blendWithMask(input: CIImage, background: CIImage, mask: CIImage) -> CIImage {
            let f = CIFilter(name: "CIBlendWithAlphaMask")!
            f.setValue(input, forKey: kCIInputImageKey)
            f.setValue(background, forKey: kCIInputBackgroundImageKey)
            f.setValue(mask, forKey: kCIInputMaskImageKey)
            return f.outputImage!.cropped(to: extent)
        }

        // Máscaras retas (top/bottom/left/right) — faixa e
        let topMask    = makeRectMask(extent: extent, rect: CGRect(x: 0, y: h - e, width: w, height: e))
        let bottomMask = makeRectMask(extent: extent, rect: CGRect(x: 0, y: 0,      width: w, height: e))
        let leftMask   = makeRectMask(extent: extent, rect: CGRect(x: 0,      y: 0, width: e, height: h))
        let rightMask  = makeRectMask(extent: extent, rect: CGRect(x: w - e,  y: 0, width: e, height: h))

        // Top: GREEN > 0.5 desloca +Y (para dentro)
        let topGrad = linearGradient(point0: CGPoint(x: 0, y: h),
                                     point1: CGPoint(x: 0, y: h - e),
                                     color0: CIColor(red: 0.5, green: 0.5 + delta, blue: 0.5, alpha: 1.0),
                                     color1: CIColor(red: 0.5, green: 0.5,         blue: 0.5, alpha: 1.0))
        base = blendWithMask(input: topGrad, background: base, mask: topMask)

        // Bottom: GREEN < 0.5 desloca -Y (para fora)
        let bottomGrad = linearGradient(point0: CGPoint(x: 0, y: 0),
                                        point1: CGPoint(x: 0, y: e),
                                        color0: CIColor(red: 0.5, green: 0.5,         blue: 0.5, alpha: 1.0),
                                        color1: CIColor(red: 0.5, green: 0.5 - delta, blue: 0.5, alpha: 1.0))
        base = blendWithMask(input: bottomGrad, background: base, mask: bottomMask)

        // Left: RED > 0.5 desloca +X (para dentro)
        let leftGrad = linearGradient(point0: CGPoint(x: 0, y: 0),
                                      point1: CGPoint(x: e, y: 0),
                                      color0: CIColor(red: 0.5 + delta, green: 0.5, blue: 0.5, alpha: 1.0),
                                      color1: CIColor(red: 0.5,         green: 0.5, blue: 0.5, alpha: 1.0))
        base = blendWithMask(input: leftGrad, background: base, mask: leftMask)

        // Right: RED < 0.5 desloca -X (para fora)
        let rightGrad = linearGradient(point0: CGPoint(x: w - e, y: 0),
                                       point1: CGPoint(x: w,     y: 0),
                                       color0: CIColor(red: 0.5,         green: 0.5, blue: 0.5, alpha: 1.0),
                                       color1: CIColor(red: 0.5 - delta, green: 0.5, blue: 0.5, alpha: 1.0))
        base = blendWithMask(input: rightGrad, background: base, mask: rightMask)

        // Cantos: leve bump radial para suavizar transição nas quinas arredondadas
        // (aproxima a direção normal da borda nos cantos)
        base = applyCornerBumps(base: base, extent: extent, borderWidth: e, cornerRadius: cornerRadius, delta: delta)

        return base
    }

    // MARK: - Helpers de máscaras
    private func makeRectMask(extent: CGRect, rect: CGRect) -> CIImage {
        // Cria uma máscara branca na região especificada, preta no resto
        UIGraphicsBeginImageContextWithOptions(extent.size, false, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return CIImage(color: CIColor.black).cropped(to: extent)
        }
        
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: extent.size))
        
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(rect)
        
        let maskUIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let maskUIImage, let maskCI = CIImage(image: maskUIImage) {
            return maskCI.cropped(to: extent)
        }
        return CIImage(color: CIColor.black).cropped(to: extent)
    }
    
    private func solidRect(_ rect: CGRect, extent: CGRect) -> CIImage {
        // Cria uma imagem branca sólida na região especificada
        let white = CIImage(color: CIColor.white).cropped(to: rect)
        let black = CIImage(color: CIColor.black).cropped(to: extent)
        
        // Composita o retângulo branco sobre o fundo preto
        if let blend = CIFilter(name: "CISourceOverCompositing") {
            blend.setValue(white, forKey: kCIInputImageKey)
            blend.setValue(black, forKey: kCIInputBackgroundImageKey)
            return blend.outputImage!.cropped(to: extent)
        }
        return white.cropped(to: extent)
    }

    /// Máscara de anel (borda) respeitando cornerRadius e borderWidth.
    private func makeRingMask(extent: CGRect, cornerRadius: CGFloat, borderWidth: CGFloat) -> CIImage {
        // Renderiza via CoreGraphics: branco no anel, preto no resto.
        UIGraphicsBeginImageContextWithOptions(extent.size, false, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: extent)
        }

        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: extent.size))

        let outerPath = UIBezierPath(roundedRect: extent, cornerRadius: cornerRadius)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.addPath(outerPath.cgPath)
        ctx.fillPath()

        let innerRect = extent.insetBy(dx: borderWidth, dy: borderWidth)
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: max(cornerRadius - borderWidth, 0))
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.addPath(innerPath.cgPath)
        ctx.fillPath()

        let maskUIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let maskUIImage, let maskCI = CIImage(image: maskUIImage) {
            return maskCI.cropped(to: extent)
        }
        return CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: extent)
    }

    /// Suaviza cantos com bumps radiais leves
    private func applyCornerBumps(base: CIImage,
                                  extent: CGRect,
                                  borderWidth: CGFloat,
                                  cornerRadius: CGFloat,
                                  delta: CGFloat) -> CIImage {
        var out = base

        func bump(center: CGPoint, radius: CGFloat, scale: CGFloat) {
            if let f = CIFilter(name: "CIBumpDistortion") {
                f.setValue(out, forKey: kCIInputImageKey)
                f.setValue(CIVector(x: center.x, y: center.y), forKey: kCIInputCenterKey)
                f.setValue(radius, forKey: kCIInputRadiusKey)
                f.setValue(scale,  forKey: kCIInputScaleKey)
                if let o = f.outputImage?.cropped(to: extent) {
                    out = o
                }
            }
        }

        // Centros aproximados das quinas dentro do anel
        let inset = borderWidth / 2
        let tl = CGPoint(x: cornerRadius - inset, y: extent.height - (cornerRadius - inset))
        let tr = CGPoint(x: extent.width - (cornerRadius - inset), y: extent.height - (cornerRadius - inset))
        let bl = CGPoint(x: cornerRadius - inset, y: cornerRadius - inset)
        let br = CGPoint(x: extent.width - (cornerRadius - inset), y: cornerRadius - inset)

        let bumpRadius = borderWidth * 1.4
        let bumpScale: CGFloat = delta // pequeno, suave

        bump(center: tl, radius: bumpRadius, scale: bumpScale)
        bump(center: tr, radius: bumpRadius, scale: bumpScale)
        bump(center: bl, radius: bumpRadius, scale: bumpScale)
        bump(center: br, radius: bumpRadius, scale: bumpScale)

        return out
    }
}

