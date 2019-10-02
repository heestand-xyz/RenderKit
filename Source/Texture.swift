//
//  PixelKitTexture.swift
//  PixelKit
//
//  Created by Hexagons on 2018-08-23.
//  Open Source - MIT License
//

import MetalKit
import VideoToolbox

public struct Texture {
    
    public enum TextureError: Error {
        case pixelBuffer(Int)
        case emptyFail
        case copy(String)
        case multi(String)
        case mipmap
    }
    
    public static func buffer(from image: CGImage, at size: CGSize?) -> CVPixelBuffer? {
        #if os(iOS) || os(tvOS)
        return buffer(from: UIImage(cgImage: image))
        #elseif os(macOS)
        guard size != nil else { return nil }
        return buffer(from: NSImage(cgImage: image, size: size!))
        #endif
    }
    
    #if os(iOS) || os(tvOS)
    public typealias _Image = UIImage
    #elseif os(macOS)
    public typealias _Image = NSImage
    #endif
    public static func buffer(from image: _Image) -> CVPixelBuffer? {
        
        #if os(iOS) || os(tvOS)
        let scale: CGFloat = image.scale
        #elseif os(macOS)
        let scale: CGFloat = 1.0
        #endif
        
        let width = image.size.width * scale
        let height = image.size.height * scale
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
//            String(kCVPixelBufferIOSurfacePropertiesKey): [
//                "IOSurfaceOpenGLESFBOCompatibility": true,
//                "IOSurfaceOpenGLESTextureCompatibility": true,
//                "IOSurfaceCoreAnimationCompatibility": true,
//                ]
            ] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         Render.main.bits.os,
                                         attrs,
                                         &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8, // FIXME: bits.rawValue,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        
        #if os(iOS) || os(tvOS)
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        #elseif os(macOS)
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        #endif
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    public enum ImagePlacement {
        case fill
        case fit
    }
    
    #if os(iOS) || os(tvOS)
    public static func resize(_ image: UIImage, to size: CGSize, placement: ImagePlacement = .fill) -> UIImage {
        
        let frame: CGRect
        switch placement {
        case .fit:
            frame = CGRect(
                x: image.size.width / size.width > image.size.height / size.height ?
                    0 : (size.width - image.size.width * (size.height / image.size.height)) / 2,
                y: image.size.width / size.width < image.size.height / size.height ?
                    0 : (size.height - image.size.height * (size.width / image.size.width)) / 2,
                width: image.size.width / size.width > image.size.height / size.height ?
                    size.width : image.size.width * (size.height / image.size.height),
                height: image.size.width / size.width < image.size.height / size.height ?
                    size.height : image.size.height * (size.width / image.size.width)
            )
        case .fill:
            frame = CGRect(
                x: image.size.width / size.width < image.size.height / size.height ?
                    0 : (size.width - image.size.width * (size.height / image.size.height)) / 2,
                y: image.size.width / size.width > image.size.height / size.height ?
                    0 : (size.height - image.size.height * (size.width / image.size.width)) / 2,
                width: image.size.width / size.width < image.size.height / size.height ?
                    size.width : image.size.width * (size.height / image.size.height),
                height: image.size.width / size.width > image.size.height / size.height ?
                    size.height : image.size.height * (size.width / image.size.width)
            )
        }
        
        UIGraphicsBeginImageContext(size)
        image.draw(in: frame)
        let resized_image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resized_image!
    }
    #endif
    
    public static func makeTexture(from pixelBuffer: CVPixelBuffer, with commandBuffer: MTLCommandBuffer, force8bit: Bool = false) throws -> MTLTexture {
//        let width = CVPixelBufferGetWidth(pixelBuffer)
//        let height = CVPixelBufferGetHeight(pixelBuffer)
//        var cvTextureOut: CVMetalTexture?
//        let colorBits: MTLPixelFormat = force8bit ? LiveColor.Bits._8.mtl : bits.mtl
//        let attributes = [
////            "IOSurfaceOpenGLESFBOCompatibility": true,
////            "IOSurfaceOpenGLESTextureCompatibility": true,
//            "IOSurfaceCoreAnimationCompatibility": true
//            ] as CFDictionary
//        let kCVReturn = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, attributes, colorBits, width, height, 0, &cvTextureOut)
//        guard kCVReturn == kCVReturnSuccess else {
//            throw TextureError.pixelBuffer(-1)
//        }
//        guard let cvTexture = cvTextureOut else {
//            throw TextureError.pixelBuffer(-2)
//        }
//        guard let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
//            throw TextureError.pixelBuffer(-3)
//        }
//        return inputTexture
        
//        guard let texture = CVMetalTextureGetTexture(pixelBuffer) else {
//            throw TextureError.pixelBuffer(-1)
//        }
//        return texture
        
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let image = cgImage else {
            throw TextureError.pixelBuffer(-4)
        }
        return try makeTexture(from: image, with: commandBuffer)
    }

    public static func makeTexture(from image: CGImage, with commandBuffer: MTLCommandBuffer) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: Render.main.metalDevice)
        let texture: MTLTexture = try textureLoader.newTexture(cgImage: image, options: nil)
        try mipmap(texture: texture, with: commandBuffer)
        return texture
    }
    
    public static func mipmap(texture: MTLTexture, with commandBuffer: MTLCommandBuffer) throws {
        guard texture.mipmapLevelCount > 1 else { return }
        guard let commandEncoder: MTLBlitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.mipmap
        }
        commandEncoder.generateMipmaps(for: texture)
        commandEncoder.endEncoding()
    }
    
    public static func emptyTexture(size: CGSize) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Render.main.bits.mtl, width: Int(size.width), height: Int(size.height), mipmapped: true)
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        guard let texture = Render.main.metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.emptyFail
        }
        return texture
    }
    
    public static func copyTexture<N: NODE>(from node: N) throws -> MTLTexture {
        guard let texture = node.texture else {
            throw TextureError.copy("NODE Texture is nil.")
        }
        return try copy(texture: texture)
    }
    
    public static func copy(texture: MTLTexture) throws -> MTLTexture {
        let textureCopy = try emptyTexture(size: CGSize(width: texture.width, height: texture.height))
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TextureError.copy("Command Buffer make failed.")
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.copy("Blit Command Encoder make failed.")
        }
        blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: textureCopy, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        //        blitEncoder.generateMipmaps(for: textureCopy)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        return textureCopy
    }
    
    public static func makeMultiTexture(from textures: [MTLTexture], with commandBuffer: MTLCommandBuffer, in3D: Bool = false) throws -> MTLTexture {
        
        guard !textures.isEmpty else {
            throw TextureError.multi("Passed Textures array is empty.")
        }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = bits.mtl
        descriptor.textureType = in3D ? .type3D : .type2DArray
        descriptor.width = textures.first!.width
        descriptor.height = textures.first!.height
        descriptor.mipmapLevelCount = textures.first?.mipmapLevelCount ?? 1
        if in3D {
            descriptor.depth = textures.count
        } else {
            descriptor.arrayLength = textures.count
        }
        
        guard let multiTexture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.multi("Texture creation failed.")
        }

        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.multi("Blit Encoder creation failed.")
        }
        
        for (i, texture) in textures.enumerated() {
            blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: multiTexture, destinationSlice: in3D ? 0 : i, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: in3D ? i : 0))
//            for j in 0..<texture.mipmapLevelCount {
//                let rawWidth = texture.width
//                let rawHeight = texture.height
//                let width = Int(CGFloat(rawWidth) / pow(2, CGFloat(j)))
//                let height = Int(CGFloat(rawHeight) / pow(2, CGFloat(j)))
//                guard width != 0 else { continue }
//                guard height != 0 else { continue }
//                blitEncoder.copy(from: texture,
//                                 sourceSlice: 0,
//                                 sourceLevel: j,
//                                 sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
//                                 sourceSize: MTLSize(width: width, height: height, depth: 1),
//                                 to: multiTexture,
//                                 destinationSlice: in3D ? 0 : i,
//                                 destinationLevel: j,
//                                 destinationOrigin: MTLOrigin(x: 0, y: 0, z: in3D ? i : 0))
//            }
        }
        blitEncoder.endEncoding()
        
        return multiTexture
    }
    
    public static func textures(from node: NODE, with commandBuffer: MTLCommandBuffer) throws -> (a: MTLTexture?, b: MTLTexture?, custom: MTLTexture?) {

        var generator: Bool = false
        var custom: Bool = false
        var inputTexture: MTLTexture? = nil
        var secondInputTexture: MTLTexture? = nil
        if let nodeContent = node as? NODEContent {
            if let nodeResource = nodeContent as? NODEResource {
                guard let pixelBuffer = nodeResource.pixelBuffer else {
                    throw RenderError.texture("Pixel Buffer is nil.")
                }
                let force8bit: Bool
                #if os(tvOS)
                force8bit = false
                #else
                force8bit = (node as? CameraNODE) != nil
                #endif
                inputTexture = try makeTexture(from: pixelBuffer, with: commandBuffer, force8bit: force8bit)
            } else if nodeContent is NODEGenerator {
                generator = true
            } else if let nodeSprite = nodeContent as? NODESprite {
                guard let spriteTexture = nodeSprite.sceneView.texture(from: nodeSprite.scene) else {
                    throw RenderError.texture("Sprite Texture fail.")
                }
                let spriteImage: CGImage = spriteTexture.cgImage()
                guard let spriteBuffer = buffer(from: spriteImage, at: nodeSprite.res.size.cg) else {
                    throw RenderError.texture("Sprite Buffer fail.")
                }
                inputTexture = try makeTexture(from: spriteBuffer, with: commandBuffer)
            } else if nodeContent is NODECustom {
                custom = true
            }
        } else if let nodeIn = node as? NODE & NODEInIO {
            if let nodeInMulti = nodeIn as? NODEInMulti {
                var inTextures: [MTLTexture] = []
                for (i, nodeOut) in nodeInMulti.inNodes.enumerated() {
                    guard let nodeOutTexture = nodeOut.texture else {
                        throw RenderError.texture("IO Texture \(i) not found for: \(nodeOut)")
                    }
                    try mipmap(texture: nodeOutTexture, with: commandBuffer)
                    inTextures.append(nodeOutTexture)
                }
                inputTexture = try makeMultiTexture(from: inTextures, with: commandBuffer)
            } else {
                guard let nodeOut = nodeIn.nodeInList.first else {
                    throw RenderError.texture("inNode not connected.")
                }
                var feed = false
                if let feedbackNode = nodeIn as? FeedbackNODE {
                    if feedbackNode.readyToFeed && feedbackNode.feedActive {
                        guard let feedTexture = feedbackNode.feedTexture else {
                            throw RenderError.texture("Feed Texture not avalible.")
                        }
                        inputTexture = feedTexture
                        feed = true
                    }
                }
                if !feed {
                    guard let nodeOutTexture = nodeOut.texture else {
                        throw RenderError.texture("IO Texture not found for: \(nodeOut)")
                    }
                    inputTexture = nodeOutTexture // CHECK copy?
                    if node is NODEInMerger {
                        let nodeOutB = nodeIn.nodeInList[1]
                        guard let nodeOutTextureB = nodeOutB.texture else {
                            throw RenderError.texture("IO Texture B not found for: \(nodeOutB)")
                        }
                        secondInputTexture = nodeOutTextureB // CHECK copy?
                    }
                }
            }
        }
        
        guard generator || custom || inputTexture != nil else {
            throw RenderError.texture("Input Texture missing.")
        }
        
        if custom {
            return (nil, nil, nil)
        }
        
        // Mipmap
        
        if inputTexture != nil {
            try mipmap(texture: inputTexture!, with: commandBuffer)
        }
        if secondInputTexture != nil {
            try mipmap(texture: secondInputTexture!, with: commandBuffer)
        }
        
        // MARK: Custom Render
        
        var customTexture: MTLTexture?
        if !generator && node.customRenderActive {
            guard let customRenderDelegate = node.customRenderDelegate else {
                throw RenderError.custom("PixelCustomRenderDelegate not implemented.")
            }
            if let customRenderedTexture = customRenderDelegate.customRender(inputTexture!, with: commandBuffer) {
                inputTexture = nil
                customTexture = customRenderedTexture
            }
        }
        
        if node is NODEInMerger {
            if !generator && node.customMergerRenderActive {
                guard let customMergerRenderDelegate = node.customMergerRenderDelegate else {
                    throw RenderError.custom("PixelCustomMergerRenderDelegate not implemented.")
                }
                let customRenderedTextures = customMergerRenderDelegate.customRender(a: inputTexture!, b: secondInputTexture!, with: commandBuffer)
                if let customRenderedTexture = customRenderedTextures {                
                    inputTexture = nil
                    secondInputTexture = nil
                    customTexture = customRenderedTexture
                }
            }
        }
        
        if let timeMachineNode = node as? TimeMachineNODE {
            let textures = timeMachineNode.customRender(inputTexture!, with: commandBuffer)
            inputTexture = try makeMultiTexture(from: textures, with: commandBuffer, in3D: true)
        }
        
        return (inputTexture, secondInputTexture, customTexture)
        
    }
    
    // MARK: - Conversions
    
    public static func ciImage(from texture: MTLTexture) -> CIImage? {
        CIImage(mtlTexture: texture, options: [.colorSpace: PixelKit.main.colorSpace.cg])
    }
    
    public static func cgImage(from ciImage: CIImage, at size: CGSize) -> CGImage? {
        guard let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent, format: bits.ci, colorSpace: colorSpace.cg) else { return nil }
        #if os(iOS) || os(tvOS)
        return cgImage
        #elseif os(macOS)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: colorSpace.cg, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -size.height)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        guard let image = context.makeImage() else { return nil }
        return image
        #endif
    }

    public static func image(from cgImage: CGImage, at size: CGSize) -> _Image {
        #if os(iOS) || os(tvOS)
        return UIImage(cgImage: cgImage, scale: 1, orientation: .downMirrored)
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }

    public static func image(from texture: MTLTexture) -> _Image? {
        let size = CGSize(width: texture.width, height: texture.height)
        guard let ciImage = ciImage(from: texture) else { return nil }
        guard let cgImage = cgImage(from: ciImage, at: size) else { return nil }
        return image(from: cgImage, at: size)
    }
    
    public static func texture(from image: _Image) -> MTLTexture? {
        #if os(iOS) || os(tvOS)
        guard let cgImage = image.cgImage else { return nil }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        #endif
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        return try? makeTexture(from: cgImage, with: commandBuffer)
    }
    
}
