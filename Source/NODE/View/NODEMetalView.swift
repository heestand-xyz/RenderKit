//
//  NODEMetalView.swift
//  PixelKit
//
//  Created by Heestand XYZ on 2018-08-07.
//  Open Source - MIT License
//


import MetalKit
import Resolution

public enum ViewInterpolation: String, CaseIterable {
    case linear
    case trilinear
    case nearest
    var filter: CALayerContentsFilter {
        switch self {
        case .linear: return .linear
        case .trilinear: return .trilinear
        case .nearest: return .nearest
        }
    }
}

public class NODEMetalView: MTKView {
    
    let render: Render
    
    public var resolution: Resolution? {
        didSet {
            guard let resolution = resolution else { return }
            drawableSize = resolution.size
        }
    }
    
    var readyToRender: (() -> ())?
    
    public var viewInterpolation: ViewInterpolation = .linear {
        didSet {
            #if os(macOS)
            wantsLayer = true
            layer?.minificationFilter = viewInterpolation.filter
            layer?.magnificationFilter = viewInterpolation.filter
            #else
            layer.minificationFilter = viewInterpolation.filter
            layer.magnificationFilter = viewInterpolation.filter
            #endif
        }
    }
   
    // MARK: - Life Cycle
    
    public init(with render: Render, pixelFormat: MTLPixelFormat) {
        
        self.render = render
        
        let onePixelFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        super.init(frame: onePixelFrame, device: render.metalDevice)
        
        colorPixelFormat = pixelFormat
        #if os(iOS) || os(tvOS)
        isOpaque = false
        #elseif os(macOS)
        layer!.isOpaque = false
        #endif
        framebufferOnly = false
        autoResizeDrawable = false
        enableSetNeedsDisplay = true
        isPaused = true
        
        #if os(macOS)
        wantsLayer = true
        layer?.minificationFilter = viewInterpolation.filter
        layer?.magnificationFilter = viewInterpolation.filter
        #else
        layer.minificationFilter = viewInterpolation.filter
        layer.magnificationFilter = viewInterpolation.filter
        #endif
        
    }
    
    // MARK: Draw
    
    override public func draw(_ rect: CGRect) {
        if rect.width > 0 && rect.height > 0 {
            if resolution != nil {
                render.logger.log(.detail, .view, "View is Ready to Render.", loop: true)
                readyToRender?()
            } else {
                render.logger.log(.warning, .view, "View Resolution not set.", loop: true)
            }
        } else {
            render.logger.log(.error, .view, "View Rect is zero.", loop: true)
        }
    }
    
    func destroy() {
        releaseDrawables()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
