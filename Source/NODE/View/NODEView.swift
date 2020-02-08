//
//  NODEView.swift
//  NodeelKit
//
//  Created by Hexagons on 2018-07-26.
//  Open Source - MIT License
//

import MetalKit
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
#if os(macOS)
@available(OSX 10.15, *)
public struct NODERepView: NSViewRepresentable {
    public let node: NODE
    public init(node: NODE) {
        self.node = node
    }
    public func makeNSView(context: Context) -> NODEView {
        return node.view
    }
    public func updateNSView(_ nodeView: NODEView, context: Context) {}
}
#else
@available(iOS 13.0.0, *)
@available(tvOS 13.0.0, *)
public struct NODERepView: UIViewRepresentable {
    public let node: NODE
    public init(node: NODE) {
        self.node = node
    }
    public func makeUIView(context: Context) -> NODEView {
        return node.view
    }
    public func updateUIView(_ nodeView: NODEView, context: Context) {}
}
#endif
@available(iOS 13.0.0, *)
@available(OSX 10.15, *)
@available(tvOS 13.0.0, *)
public struct RawNODEUI: View, NODEUI {
    public let node: NODE
    public var body: some View {
        NODERepView(node: node)
    }
    public init(node: NODE) {
        self.node = node
    }
}
#endif

#if os(iOS) || os(tvOS)
public typealias _View = UIView
#elseif os(macOS)
public typealias _View = NSView
#endif
open class NODEView: _View {
    
    let render: Render
    
    public let metalView: NODEMetalView

    public var resolution: Resolution? {
        didSet {
            resolutionSize = resolution?.size.cg
        }
    }
    public var resolutionSize: CGSize?

    public var boundsReady: Bool { return bounds.width > 0 }

    public enum Placement {
        case aspectFit
        case aspectFill
        case nodeelPerfect
        case fill
    }
    /// Defaults to `.aspectFit`.
    public var placement: Placement = .aspectFit { didSet { layoutPlacement() } }
    
    var widthLayoutConstraint: NSLayoutConstraint!
    var heightLayoutConstraint: NSLayoutConstraint!
    
    /// This enables a checker background view, the default is `true`.
    /// Disable if you have a transparent NODE and want views under the NODEView to show.
    public var checker: Bool = true { didSet { checkerView.isHidden = !checker/* || !NodeelKit.main.backgroundAlphaCheckerActive*/ } }
    let checkerView: CheckerView
    
    #if os(macOS)
    public override var frame: NSRect { didSet { _ = layoutPlacement(); checkAutoRes() } }
    #endif
    
    public init(with render: Render, pixelFormat: MTLPixelFormat) {
        
        self.render = render
        
        checkerView = CheckerView()

        metalView = NODEMetalView(with: render, pixelFormat: pixelFormat)
        
        super.init(frame: .zero)
        
        #if os(iOS) || os(tvOS)
        clipsToBounds = true
        #endif
        
//        checkerView.isHidden = !NodeelKit.main.backgroundAlphaCheckerActive
        addSubview(checkerView)
        
        addSubview(metalView)
        
        autoLayout()
        
    }
    
    open func autoLayout() {
        
        checkerView.translatesAutoresizingMaskIntoConstraints = false
        checkerView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        checkerView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        checkerView.widthAnchor.constraint(equalTo: metalView.widthAnchor).isActive = true
        checkerView.heightAnchor.constraint(equalTo: metalView.heightAnchor).isActive = true
        
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        metalView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        widthLayoutConstraint = metalView.widthAnchor.constraint(equalToConstant: 1)
        heightLayoutConstraint = metalView.heightAnchor.constraint(equalToConstant: 1)
        widthLayoutConstraint.isActive = true
        heightLayoutConstraint.isActive = true
        
    }
    
    func layoutPlacement() {
        
        guard boundsReady else { return }
        guard let res = resolution else { return }
        
        let resolutionAspect = res.width.cg / res.height.cg
        let viewAspect = bounds.width / bounds.height
        let combinedAspect = resolutionAspect / viewAspect
        let dynamicAspect = resolutionAspect > viewAspect ? combinedAspect : 1 / combinedAspect
        
        let width: CGFloat
        let height: CGFloat
        switch placement {
        case .aspectFit:
            width = resolutionAspect >= viewAspect ? bounds.width : bounds.width / dynamicAspect
            height = resolutionAspect <= viewAspect ? bounds.height : bounds.height / dynamicAspect
        case .aspectFill:
            width = resolutionAspect <= viewAspect ? bounds.width : bounds.width * dynamicAspect
            height = resolutionAspect >= viewAspect ? bounds.height : bounds.height * dynamicAspect
        case .nodeelPerfect:
            let scale: CGFloat = Resolution.scale.cg
            width = res.width.cg / scale
            height = res.height.cg / scale
        case .fill:
            width = bounds.width
            height = bounds.height
        }
        
        widthLayoutConstraint.constant = width
        heightLayoutConstraint.constant = height
        
        #if os(iOS) || os(tvOS)
        checkerView.setNeedsDisplay()
        #elseif os(macOS)
//        metalView.setNeedsDisplay(frame)
//        checkerView.setNeedsDisplay(frame)
//        layoutSubtreeIfNeeded()
//        metalView.needsLayout = true
//        metalView.needsUpdateConstraints = true
        #endif
        
    }
    
    public func setResolution(_ newResolution: Resolution?) {
        
        if let resolution = newResolution {
            self.resolution = resolution
            metalView.resolution = resolution
            layoutPlacement()
        } else {
            self.resolution = nil
            widthLayoutConstraint.constant = 0
            heightLayoutConstraint.constant = 0
            #if os(iOS) || os(tvOS)
            checkerView.setNeedsDisplay()
            #endif
            metalView.resolution = nil
        }
        
        // FIXME: Set by user..
//        if !boundsReady {
//            #if os(iOS) || os(tvOS)
//            let scale: CGFloat = UIScreen.main.nativeScale
//            #elseif os(macOS)
//            let scale: CGFloat = 1.0
//            #endif
//            frame = CGRect(x: 0, y: 0, width: newRes.width / scale, height: newRes.height / scale)
//        }
    }
    
    #if os(iOS) || os(tvOS)
    public override func layoutSubviews() {
        super.layoutSubviews()
        _ = layoutPlacement()
        checkAutoRes()
    }
    #elseif os(macOS)
    public override func layout() {
        super.layout()
        _ = layoutPlacement()
        checkAutoRes()
    }
    #endif
    
    func checkAutoRes() {
        for node in render.linkedNodes {
            if let nodeRes = node as? NODEResolution {
                if nodeRes.resolution.size.cg != resolutionSize {
                    node.applyResolution {
                        node.setNeedsRender()
                    }
                }
            }
        }
    }
    
    public func destroy() {
        metalView.destroy()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
