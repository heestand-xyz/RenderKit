//
//  PixelKitTexture.swift
//  PixelKit
//
//  Created by Hexagons on 2018-08-23.
//  Open Source - MIT License
//

import CoreGraphics
import LiveValues
import MetalKit
import VideoToolbox
import Accelerate

public struct Texture {
    
    public enum TextureError: Error {
        case pixelBuffer(Int)
        case emptyFail
        case copy(String)
        case multi(String)
        case mipmap
        case raw(String)
        case makeTexture(String)
    }
    
    public static func buffer(from image: CGImage, at size: CGSize?, bits: LiveColor.Bits? = nil, swizzel: Bool = false) -> CVPixelBuffer? {
        guard let bits: LiveColor.Bits = bits ?? LiveColor.Bits(rawValue: image.bitsPerPixel) else {
            return nil
        }
        #if os(iOS) || os(tvOS)
        return buffer(from: UIImage(cgImage: image), bits: bits, swizzel: swizzel)
        #elseif os(macOS)
        guard size != nil else { return nil }
        return buffer(from: NSImage(cgImage: image, size: size!), bits: bits)
        #endif
    }
    
    #if os(iOS) || os(tvOS)
    public typealias _Image = UIImage
    #elseif os(macOS)
    public typealias _Image = NSImage
    #endif
    public static func buffer(from image: _Image, bits: LiveColor.Bits, swizzel: Bool = false) -> CVPixelBuffer? {
        
        #if os(iOS) || os(tvOS)
        let scale: CGFloat = image.scale
        #elseif os(macOS)
        var scale: CGFloat = 1.0
        if let pixelsWide: Int = image.representations.first?.pixelsWide {
            scale = CGFloat(pixelsWide) / image.size.width
        }
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
                                         swizzel ? kCVPixelFormatType_32ARGB : bits.os,
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
                                      bitmapInfo: swizzel ? CGImageAlphaInfo.premultipliedFirst.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)
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
    
    public static func resize(_ image: _Image, to size: CGSize, placement: ImagePlacement = .fill) -> _Image {
        
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

        #if os(iOS) || os(tvOS)
        
        UIGraphicsBeginImageContext(size)
        image.draw(in: frame)
        let resized_image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        #elseif os(macOS)
       
        let sourceRect = NSMakeRect(0, 0, image.size.width, image.size.height)
        let destSize = NSMakeSize(frame.width, frame.height)
        let destRect = NSMakeRect(0, 0, destSize.width, destSize.height)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image.draw(in: destRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        newImage.size = destSize
        let resized_image = NSImage(data: newImage.tiffRepresentation!)!
        
        #endif
        
        return resized_image
    }
    
    public static func ciImage(from pixelBuffer: CVPixelBuffer) -> CIImage {
        CIImage(cvImageBuffer: pixelBuffer)
    }
    
    /// Check out makeTextureFromCache first...
    public static func makeTexture(from pixelBuffer: CVPixelBuffer, with commandBuffer: MTLCommandBuffer, force8bit: Bool = false, on metalDevice: MTLDevice) throws -> MTLTexture {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let image = cgImage else {
            throw TextureError.makeTexture("Pixel Buffer to Metal Texture Converion Faied with VTCreate method.")
        }
        return try makeTexture(from: image, with: commandBuffer, on: metalDevice)
    }
    
    public static func makeTexture(from ciImage: CIImage, at size: CGSize, colorSpace: LiveColor.Space, bits: LiveColor.Bits, with commandBuffer: MTLCommandBuffer, on metalDevice: MTLDevice, vFlip: Bool = true) throws -> MTLTexture {
        guard let image: CGImage = cgImage(from: ciImage, at: size, colorSpace: colorSpace, bits: bits, vFlip: vFlip) else {
            throw TextureError.makeTexture("CIImage to CGImage conversion failed.")
        }
        return try makeTexture(from: image, with: commandBuffer, on: metalDevice)
    }

    public static func makeTexture(from image: CGImage, with commandBuffer: MTLCommandBuffer, on metalDevice: MTLDevice) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: metalDevice)
        let texture: MTLTexture = try textureLoader.newTexture(cgImage: image, options: nil)
        try mipmap(texture: texture, with: commandBuffer)
        return texture
    }
    
    public static func makeTextureFromCache(from pixelBuffer: CVPixelBuffer, bits: LiveColor.Bits, in textureCache: CVMetalTextureCache) throws -> MTLTexture {
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let channelCount = bytesPerRow / width
        let pixelFormat: MTLPixelFormat
        switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
        case 1278226534: // OneComponent32Float
            pixelFormat = LiveColor.Bits._32.monochromePixelFormat
        default:
            switch channelCount {
            case 4: pixelFormat = bits.pixelFormat
            case 2: pixelFormat = LiveColor.Bits._16.monochromePixelFormat
            default: pixelFormat = bits.pixelFormat
            }
        }
        
        var imageTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, pixelFormat, width, height, 0, &imageTexture)
        
        guard let unwrappedImageTexture = imageTexture,
              let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
              result == kCVReturnSuccess else {
            throw TextureError.makeTexture("Pixel Buffer to Metal Texture Converion Faied with result: \(result)")
        }

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
    
    public static func emptyTexture(size: CGSize, bits: LiveColor.Bits, on metalDevice: MTLDevice, write: Bool = false/*, makeIOSurface: Bool = false*/) throws -> MTLTexture {
        guard size.width > 0 && size.height > 0 else { throw TextureError.emptyFail }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: bits.pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: true)
        descriptor.usage = MTLTextureUsage(rawValue: write ? (MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue) : (MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue))
//        descriptor.swizzle...
//        let emptyTexture: MTLTexture
//        if makeIOSurface {
//            guard var ioSurface: IOSurface = IOSurface(properties: [
//                IOSurfacePropertyKey.pixelFormat : bits.pixelFormat,
//                IOSurfacePropertyKey.width : Int(size.width),
//                IOSurfacePropertyKey.height : Int(size.height)
//            ]) else {
//                throw TextureError.emptyFail
//            }
//            guard let texture = metalDevice.makeTexture(descriptor: descriptor, iosurface: ioSurface.ref, plane: 0) else {
//                throw TextureError.emptyFail
//            }
//            emptyTexture = texture
//        } else {
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.emptyFail
        }
//            emptyTexture = texture
//        }
        return texture
    }
    
    public static func emptyTextureCube(size: Int, bits: LiveColor.Bits, on metalDevice: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: bits.pixelFormat, size: size, mipmapped: false)
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.emptyFail
        }
        return texture
    }
    
    public static func emptyTexture3D(at resolution: Resolution3D, bits: LiveColor.Bits, on metalDevice: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = bits.pixelFormat
        descriptor.textureType = .type3D
        descriptor.width = resolution.raw.x
        descriptor.height = resolution.raw.y
        descriptor.depth = resolution.raw.z
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.emptyFail
        }
        return texture
    }
    
    public static func copyTexture<N: NODE>(from node: N, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> MTLTexture {
        guard let texture = node.texture else {
            throw TextureError.copy("NODE Texture is nil.")
        }
        return try copy(texture: texture, on: metalDevice, in: commandQueue)
    }
    
    public static func copy(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> MTLTexture {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.copy("Bits not found.")
        }
        let textureCopy = try emptyTexture(size: CGSize(width: texture.width, height: texture.height), bits: bits, on: metalDevice)
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
    
    public static func mergeTiles2d(textures: [[MTLTexture]], on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> MTLTexture {
        guard !textures.isEmpty && !textures.first!.isEmpty else {
            throw TextureError.copy("Tile textures not found.")
        }
        let firstTexture = textures.first!.first!
        let width = firstTexture.width
        let height = firstTexture.height
        let fullWidth = width * textures.first!.count
        let fullHeight = height * textures.count
        guard let bits = LiveColor.Bits.bits(for: firstTexture.pixelFormat) else {
            throw TextureError.copy("Tile bits not found.")
        }
        let textureCopy = try emptyTexture(size: CGSize(width: fullWidth, height: fullHeight), bits: bits, on: metalDevice)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TextureError.copy("Tile command Buffer make failed.")
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.copy("Tile blit Command Encoder make failed.")
        }
        for (y, row) in textures.enumerated() {
            for (x, texture) in row.enumerated() {
                let sourceOrigin = MTLOrigin(x: 0, y: 0, z: 0)
                let sourceSize = MTLSize(width: width, height: height, depth: 1)
                let destinationOrigin = MTLOrigin(x: x * width, y: y * height, z: 0)
                blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: sourceOrigin, sourceSize: sourceSize, to: textureCopy, destinationSlice: 0, destinationLevel: 0, destinationOrigin: destinationOrigin)
            }
        }
        blitEncoder.endEncoding()
        commandBuffer.commit()
        return textureCopy
    }
    
    public static func mergeTiles3d(textures: [[[MTLTexture]]], on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> MTLTexture {
        guard !textures.isEmpty && !textures.first!.isEmpty && !textures.first!.first!.isEmpty else {
            throw TextureError.copy("Tile textures not found.")
        }
        let firstTexture = textures.first!.first!.first!
        let width = firstTexture.width
        let height = firstTexture.height
        let depth = firstTexture.depth
        let fullWidth = width * textures.first!.first!.count
        let fullHeight = height * textures.first!.count
        let fullDetph = depth * textures.count
        guard let bits = LiveColor.Bits.bits(for: firstTexture.pixelFormat) else {
            throw TextureError.copy("Tile bits not found.")
        }
        let textureCopy = try emptyTexture3D(at: .custom(x: fullWidth, y: fullHeight, z: fullDetph), bits: bits, on: metalDevice)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TextureError.copy("Tile command Buffer make failed.")
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.copy("Tile blit Command Encoder make failed.")
        }
        for (z, grid) in textures.enumerated() {
            for (y, row) in grid.enumerated() {
                for (x, texture) in row.enumerated() {
                    let sourceOrigin = MTLOrigin(x: 0, y: 0, z: 0)
                    let sourceSize = MTLSize(width: width, height: height, depth: depth)
                    let destinationOrigin = MTLOrigin(x: x * width, y: y * height, z: z * depth)
                    blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: sourceOrigin, sourceSize: sourceSize, to: textureCopy, destinationSlice: 0, destinationLevel: 0, destinationOrigin: destinationOrigin)
                }
            }
        }
        blitEncoder.endEncoding()
        commandBuffer.commit()
        return textureCopy
    }
    
    public static func copy3D(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> MTLTexture {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.copy("Bits not found.")
        }
        let textureCopy = try emptyTexture3D(at: .custom(x: texture.width, y: texture.height, z: texture.depth), bits: bits, on: metalDevice)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TextureError.copy("Command Buffer make failed.")
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.copy("Blit Command Encoder make failed.")
        }
        blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: texture.width, height: texture.height, depth: texture.depth), to: textureCopy, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
//        blitEncoder.generateMipmaps(for: textureCopy)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        return textureCopy
    }
    
    public static func makeMultiTexture(from textures: [MTLTexture], with commandBuffer: MTLCommandBuffer, on metalDevice: MTLDevice, in3D: Bool = false) throws -> MTLTexture {
        
        guard !textures.isEmpty else {
            throw TextureError.multi("Passed textures array is empty.")
        }
        let width = textures.first!.width
        let height = textures.first!.height
        guard textures.filter({ texture -> Bool in
            texture.width == width && texture.height == height
        }).count == textures.count else {
            throw TextureError.multi("Passed textures are not all the same resolution.")
        }
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = textures.first!.pixelFormat
        descriptor.textureType = in3D ? .type3D : .type2DArray
        descriptor.width = width
        descriptor.height = height
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
    
    // MARK: - Conversions
    
    public static func cgImage(from texture: MTLTexture, colorSpace: LiveColor.Space, bits: LiveColor.Bits, vFlip: Bool = true) -> CGImage? {
        guard let ciImage: CIImage = ciImage(from: texture, colorSpace: colorSpace) else { return nil }
        let size = CGSize(width: texture.width, height: texture.height)
        guard let cgImage: CGImage = cgImage(from: ciImage, at: size, colorSpace: colorSpace, bits: bits, vFlip: vFlip) else { return nil }
        return cgImage
    }
    
    public static func ciImage(from texture: MTLTexture, colorSpace: LiveColor.Space) -> CIImage? {
        CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace.cg])
    }
    
    public static func cgImage(from ciImage: CIImage, at size: CGSize, colorSpace: LiveColor.Space, bits: LiveColor.Bits, vFlip: Bool = true) -> CGImage? {
        guard let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent, format: bits.ci, colorSpace: colorSpace.cg) else { return nil }
        #if os(iOS) || os(tvOS)
        let flip: Bool = vFlip
        #elseif os(macOS)
        let flip: Bool = true
        #endif
        if flip {
            guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: colorSpace.cg, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: -size.height)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            guard let image = context.makeImage() else { return nil }
            return image
        } else {
            #if os(iOS) || os(tvOS)
            return cgImage
            #endif
        }
    }

    public static func image(from cgImage: CGImage, at size: CGSize) -> _Image {
        #if os(iOS) || os(tvOS)
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up) // .downMirrored
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }

    public static func image(from texture: MTLTexture, colorSpace: LiveColor.Space, vFlip: Bool = true) -> _Image? {
        let size = CGSize(width: texture.width, height: texture.height)
        guard let ciImage = ciImage(from: texture, colorSpace: colorSpace) else { return nil }
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else { return nil }
        guard let cgImage = cgImage(from: ciImage, at: size, colorSpace: colorSpace, bits: bits, vFlip: vFlip) else { return nil }
        return image(from: cgImage, at: size)
    }
    
    public static func texture(from image: _Image, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) -> MTLTexture? {
        #if os(iOS) || os(tvOS)
        guard let cgImage = image.cgImage else { return nil }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        #endif
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        return try? makeTexture(from: cgImage, with: commandBuffer, on: metalDevice)
    }
    
    enum PixelBufferError: Error {
        case status(String)
        case cgImage
    }
    
    public static func pixelBuffer(from image: _Image, colorSpace: LiveColor.Space, bits: LiveColor.Bits) throws -> CVPixelBuffer {
        #if os(iOS) || os(tvOS)
        guard let cgImage = image.cgImage else { throw PixelBufferError.cgImage }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw PixelBufferError.cgImage }
        #endif
        return try pixelBuffer(from: cgImage, colorSpace: colorSpace, bits: bits)
    }
    
    public static func pixelBuffer(from cgImage: CGImage, colorSpace: LiveColor.Space, bits: LiveColor.Bits) throws -> CVPixelBuffer {
        var maybePixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(bits.os) as CFNumber,
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         cgImage.width,
                                         cgImage.height,
                                         bits.os,
                                         attrs as CFDictionary,
                                         &maybePixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
            throw PixelBufferError.status("CVPixelBufferCreate failed with status \(status)")
        }
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
            throw PixelBufferError.status("CVPixelBufferLockBaseAddress failed.")
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                      width: cgImage.width,
                                      height: cgImage.height,
                                      bitsPerComponent: bits.rawValue,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: colorSpace.cg,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw PixelBufferError.status("Context failed to be created.")
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return pixelBuffer
    }
    
    public static func pixelBuffer(from texture: MTLTexture, at size: CGSize, colorSpace: LiveColor.Space, bits: LiveColor.Bits, vFlip: Bool = true) throws -> CVPixelBuffer {
        guard let ciImage: CIImage = Texture.ciImage(from: texture, colorSpace: colorSpace) else {
            throw PixelBufferError.status("CIImage failed.")
        }
        guard let cgImage: CGImage = Texture.cgImage(from: ciImage, at: size, colorSpace: colorSpace, bits: bits, vFlip: vFlip) else {
            throw PixelBufferError.status("CGImage failed.")
        }
        let pixelBuffer: CVPixelBuffer = try Texture.pixelBuffer(from: cgImage, colorSpace: colorSpace, bits: bits)
        return pixelBuffer
    }
    
    // MARK: - Raw
    
    public static func raw8(texture: MTLTexture) throws -> [UInt8] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 8 - Texture bits out of range.")
        }
        guard bits == ._8 else {
            throw TextureError.raw("Raw 8 - To access this data, the texture needs to be in 8 bit.")
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    public static func rawCopy8(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [UInt8] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 8 - Texture bits out of range.")
        }
        guard bits == ._8 else {
            throw TextureError.raw("Raw 8 - To access this data, the texture needs to be in 8 bit.")
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TextureError.raw("Raw 8 - Command buffer could not be created.")
        }
        let bytesPerTexture = MemoryLayout<UInt8>.size * texture.width * texture.height * 4
        let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
        guard let imageBuffer = metalDevice.makeBuffer(length: bytesPerTexture, options: []) else {
            throw TextureError.raw("Raw 8 - Image buffer could not be created.")
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.raw("Raw 8 - Blit encoder could not be created.")
        }
        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                         to: imageBuffer,
                         destinationOffset: 0,
                         destinationBytesPerRow: bytesPerRow,
                         destinationBytesPerImage: 0)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * 4)
        memcpy(&raw, imageBuffer.contents(), imageBuffer.length)
        return raw
    }
    
    public static func raw3d8(texture: MTLTexture) throws -> [UInt8] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 8 - Texture bits out of range.")
        }
        guard bits == ._8 else {
            throw TextureError.raw("Raw 8 - To access this data, the texture needs to be in 8 bit.")
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<UInt8>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    public static func rawCopy3d8(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [UInt8] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 8 - Texture bits out of range.")
        }
        guard bits == ._8 else {
            throw TextureError.raw("Raw 8 - To access this data, the texture needs to be in 8 bit.")
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TextureError.raw("Raw 8 - Command buffer could not be created.")
        }
        let bytesPerTexture = MemoryLayout<UInt8>.size * texture.width * texture.height * texture.depth * 4
        let bytesPerGrid = MemoryLayout<UInt8>.size * texture.width * texture.height * 4
        let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
        guard let imageBuffer = metalDevice.makeBuffer(length: bytesPerTexture, options: []) else {
            throw TextureError.raw("Raw 8 - Image buffer could not be created.")
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TextureError.raw("Raw 8 - Blit encoder could not be created.")
        }
        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: texture.width,
                                             height: texture.height,
                                             depth: texture.depth),
                         to: imageBuffer,
                         destinationOffset: 0,
                         destinationBytesPerRow: bytesPerRow,
                         destinationBytesPerImage: bytesPerGrid)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * texture.depth * 4)
        memcpy(&raw, imageBuffer.contents(), imageBuffer.length)
        return raw
    }
    
    #if !targetEnvironment(macCatalyst)
    
    public static func raw16(texture: MTLTexture) throws -> [Float16] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 16 - Texture bits out of range.")
        }
        guard bits == ._16 else {
            throw TextureError.raw("Raw 16 - To access this data, the texture needs to be in 16 bit.")
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float16>(repeating: 0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float16>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }

    public static func raw3d16(texture: MTLTexture) throws -> [Float16] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 16 - Texture bits out of range.")
        }
        guard bits == ._16 else {
            throw TextureError.raw("Raw 16 - To access this data, the texture needs to be in 16 bit.")
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<Float16>(repeating: 0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float16>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<Float16>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    #endif
    
//    public static func rawCopy3d16(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [Float] {
//        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
//            throw TextureError.raw("Raw 16 - Texture bits out of range.")
//        }
//        guard bits == ._16 else {
//            throw TextureError.raw("Raw 16 - To access this data, the texture needs to be in 16 bit.")
//        }
//        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
//            throw TextureError.raw("Raw 16 - Command buffer could not be created.")
//        }
//        let bytesPerTexture = MemoryLayout<Float>.size * texture.width * texture.height * texture.depth * 4
//        let bytesPerGrid = MemoryLayout<Float>.size * texture.width * texture.height * 4
//        let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
//        guard let imageBuffer = metalDevice.makeBuffer(length: bytesPerTexture, options: []) else {
//            throw TextureError.raw("Raw 16 - Image buffer could not be created.")
//        }
//        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
//            throw TextureError.raw("Raw 16 - Blit encoder could not be created.")
//        }
//        blitEncoder.copy(from: texture,
//                         sourceSlice: 0,
//                         sourceLevel: 0,
//                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
//                         sourceSize: MTLSize(width: texture.width,
//                                             height: texture.height,
//                                             depth: texture.depth),
//                         to: imageBuffer,
//                         destinationOffset: 0,
//                         destinationBytesPerRow: bytesPerRow,
//                         destinationBytesPerImage: bytesPerGrid)
//        blitEncoder.endEncoding()
//        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
//        var raw = Array<Float>(repeating: 0, count: texture.width * texture.height * texture.depth * 4)
//        memcpy(&raw, imageBuffer.contents(), imageBuffer.length)
//        return raw
//    }
    
    // CHECK needs testing
    public static func raw32(texture: MTLTexture) throws -> [SIMD4<Float>] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 32 - Texture bits out of range.")
        }
        guard bits == ._32 else {
            throw TextureError.raw("Raw 32 - To access this data, the texture needs to be in 32 bit.")
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<SIMD4<Float>>(repeating: SIMD4<Float>(), count: texture.width * texture.height)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<SIMD4<Float>>.size * texture.width
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    // CHECK needs testing
    public static func raw3d32(texture: MTLTexture) throws -> [SIMD4<Float>] {
        guard let bits = LiveColor.Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 32 - Texture bits out of range.")
        }
        guard bits == ._32 else {
            throw TextureError.raw("Raw 32 - To access this data, the texture needs to be in 32 bit.")
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<SIMD4<Float>>(repeating: SIMD4<Float>(), count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<SIMD4<Float>>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<SIMD4<Float>>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    public static func rawNormalized(texture: MTLTexture, bits: LiveColor.Bits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._10:
            throw TextureError.raw("Raw 10 - Not supported.")
        case ._16:
            #if !targetEnvironment(macCatalyst)
            raw = try raw16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
            #else
            raw = []
            #endif
        case ._32:
            let rawArr = try raw32(texture: texture)
            var rawFlatArr: [CGFloat] = []
            for pixel in rawArr {
                // CHECK normalize
                rawFlatArr.append(CGFloat(pixel.x))
                rawFlatArr.append(CGFloat(pixel.y))
                rawFlatArr.append(CGFloat(pixel.z))
                rawFlatArr.append(CGFloat(pixel.w))
            }
            raw = rawFlatArr
        }
        return raw
    }
    
    public static func rawNormalizedCopy(texture: MTLTexture, bits: LiveColor.Bits, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try rawCopy8(texture: texture, on: metalDevice, in: commandQueue).map({ chan -> CGFloat in
                return CGFloat(chan) / (pow(2, 8) - 1)
            })
        default:
            throw TextureError.raw("rawNormalizedCopy with \(bits.rawValue)bits is not supported.")
        }
        return raw
    }
    
    public static func rawNormalized3d(texture: MTLTexture, bits: LiveColor.Bits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw3d8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._10:
            throw TextureError.raw("Raw 10 - Not supported.")
        case ._16:
            #if !targetEnvironment(macCatalyst)
            raw = try raw3d16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) }) // CHECK normalize
            #else
            raw = []
            #endif
        case ._32:
            let rawArr = try raw3d32(texture: texture)
            var rawFlatArr: [CGFloat] = []
            for pixel in rawArr {
                // CHECK normalize
                rawFlatArr.append(CGFloat(pixel.x))
                rawFlatArr.append(CGFloat(pixel.y))
                rawFlatArr.append(CGFloat(pixel.z))
                rawFlatArr.append(CGFloat(pixel.w))
            }
            raw = rawFlatArr
        }
        return raw
    }
    
    public static func rawNormalizedCopy3d(texture: MTLTexture, bits: LiveColor.Bits, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try rawCopy3d8(texture: texture, on: metalDevice, in: commandQueue).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
//        case ._16:
//            raw = try rawCopy3d16(texture: texture, on: metalDevice, in: commandQueue).map({ chan -> CGFloat in return CGFloat(chan) })
        default:
            throw TextureError.raw("rawNormalizedCopy3d with \(bits.rawValue)bits is not supported.")
        }
        return raw
    }
    
    // MARK: - Rotate
    
    public static func rotate90(pixelBuffer srcPixelBuffer: CVPixelBuffer, factor: UInt8) -> CVPixelBuffer? {
      let flags = CVPixelBufferLockFlags(rawValue: 0)
      guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(srcPixelBuffer, flags) else {
        return nil
      }
      defer { CVPixelBufferUnlockBaseAddress(srcPixelBuffer, flags) }

      guard let srcData = CVPixelBufferGetBaseAddress(srcPixelBuffer) else {
        print("Error: could not get pixel buffer base address")
        return nil
      }
      let sourceWidth = CVPixelBufferGetWidth(srcPixelBuffer)
      let sourceHeight = CVPixelBufferGetHeight(srcPixelBuffer)
      var destWidth = sourceHeight
      var destHeight = sourceWidth
      var color = UInt8(0)

      if factor % 2 == 0 {
        destWidth = sourceWidth
        destHeight = sourceHeight
      }

      let srcBytesPerRow = CVPixelBufferGetBytesPerRow(srcPixelBuffer)
      var srcBuffer = vImage_Buffer(data: srcData,
                                    height: vImagePixelCount(sourceHeight),
                                    width: vImagePixelCount(sourceWidth),
                                    rowBytes: srcBytesPerRow)

      let destBytesPerRow = destWidth*4
      guard let destData = malloc(destHeight*destBytesPerRow) else {
        print("rotate90 Error: out of memory")
        return nil
      }
      var destBuffer = vImage_Buffer(data: destData,
                                     height: vImagePixelCount(destHeight),
                                     width: vImagePixelCount(destWidth),
                                     rowBytes: destBytesPerRow)

      let error = vImageRotate90_ARGB8888(&srcBuffer, &destBuffer, factor, &color, vImage_Flags(0))
      if error != kvImageNoError {
        print("rotate90 Error:", error)
        free(destData)
        return nil
      }

      let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
        if let ptr = ptr {
          free(UnsafeMutableRawPointer(mutating: ptr))
        }
      }

      let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
      var dstPixelBuffer: CVPixelBuffer?
      let status = CVPixelBufferCreateWithBytes(nil, destWidth, destHeight,
                                                pixelFormat, destData,
                                                destBytesPerRow, releaseCallback,
                                                nil, nil, &dstPixelBuffer)
      if status != kCVReturnSuccess {
        print("rotate90 Error: could not create new pixel buffer")
        free(destData)
        return nil
      }
      return dstPixelBuffer
    }
    
    static func ioSurfaceCompatibility(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        
        let attributes = [
            "IOSurfaceCoreAnimationCompatibility": NSNumber(value: true)
        ]
        var copy: CVPixelBuffer? = nil

        CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), CVPixelBufferGetPixelFormatType(pixelBuffer), attributes as CFDictionary, &copy)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        if let copy = copy {
            CVPixelBufferLockBaseAddress(copy, [])
        }

        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        var copyBaseAddress: UnsafeMutableRawPointer? = nil
        if let copy = copy {
            copyBaseAddress = CVPixelBufferGetBaseAddress(copy)
        }

        memcpy(copyBaseAddress, baseAddress, CVPixelBufferGetDataSize(pixelBuffer))

        if let copy = copy {
            CVPixelBufferUnlockBaseAddress(copy, [])
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        return copy

    }
    
}
