//
//  PixelKitTexture.swift
//  PixelKit
//
//  Created by Heestand XYZ on 2018-08-23.
//  Open Source - MIT License
//

import CoreGraphics
import MetalKit
import VideoToolbox
import Accelerate
import Resolution

public protocol ChannelType {
    static var bits: Bits { get }
    var as8bit: UInt8 { get }
    var as32bit: Float { get }
}
extension UInt8: ChannelType {
    public static let bits: Bits = ._8
    public var as8bit: UInt8 {
        self
    }
    public var as32bit: Float {
        Float(self) / 255
    }
}
extension Float: ChannelType {
    public static let bits: Bits = ._32
    public var as8bit: UInt8 {
        UInt8(min(max(self * 255, 0), 255))
    }
    public var as32bit: Float {
        self
    }
}

public struct Texture {
    
    public enum TextureError: Error {
        case pixelBuffer(Int)
        case emptyFail
        case cgImage
        case copy(String)
        case multi(String)
        case mipmap
        case raw(String)
        case makeTexture(String)
    }
    
    public static func buffer(from image: CGImage, at size: CGSize?, bits: Bits? = nil, swizzel: Bool = false) -> CVPixelBuffer? {
        guard let bits: Bits = bits ?? Bits(rawValue: image.bitsPerPixel) else {
            return nil
        }
        #if os(iOS) || os(tvOS)
        return buffer(from: UIImage(cgImage: image), bits: bits, swizzel: swizzel)
        #elseif os(macOS)
        guard size != nil else { return nil }
        return buffer(from: NSImage(cgImage: image, size: size!), bits: bits)
        #endif
    }
    
    public static func cgImage(from image: _Image) -> CGImage? {
        #if os(macOS)
        var imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
        #else
        return image.cgImage
        #endif
    }
    
    public static func image(from cgImage: CGImage) -> _Image {
        #if os(macOS)
        return _Image(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
        #else
        return _Image(cgImage: cgImage)
        #endif
    }
    
    public static func loadTexture(from image: _Image, device: MTLDevice) throws -> MTLTexture {
        guard let cgImage: CGImage = Texture.cgImage(from: image) else {
            throw TextureError.cgImage
        }
        return try Texture.loadTexture(from: cgImage, device: device)
    }
    
    public static func loadTexture(from cgImage: CGImage, device: MTLDevice) throws -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        return try loader.newTexture(cgImage: cgImage, options: nil)
    }
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    public static func pixelbuffer16(from image: _Image, device: MTLDevice, colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()) -> CVPixelBuffer? {
        guard let cgImage: CGImage = Texture.cgImage(from: image) else { return nil }
        guard let texture: MTLTexture = Texture.texture16(from: cgImage, size: image.size, device: device) else { return nil }
        return try? Texture.pixelBuffer(from: texture, at: image.size, colorSpace: colorSpace, bits: ._16)
    }
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    public static func texture16(from image: _Image, device: MTLDevice) -> MTLTexture? {
        guard let cgImage: CGImage = Texture.cgImage(from: image) else { return nil }
        return Texture.texture16(from: cgImage, size: image.size, device: device)
    }
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    public static func texture16(from image: CGImage, size: CGSize, device: MTLDevice) -> MTLTexture? {
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                                                                  width: Int(size.width),
                                                                  height: Int(size.height),
                                                                  mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        if image.bitsPerComponent == 16 && image.bitsPerPixel == 64 {
            let srcData: CFData! = image.dataProvider?.data
            CFDataGetBytePtr(srcData).withMemoryRebound(to: UInt16.self, capacity: image.width * image.height * 4) { srcPixels in
                texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height),
                                mipmapLevel: 0,
                                withBytes: srcPixels,
                                bytesPerRow: MemoryLayout<UInt16>.size * 4 * image.width)
            }
        }

        return texture
    }
    
    #if os(iOS) || os(tvOS)
    public typealias _Image = UIImage
    #elseif os(macOS)
    public typealias _Image = NSImage
    #endif
    public static func buffer(from image: _Image, bits: Bits, swizzel: Bool = false) -> CVPixelBuffer? {
        
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
//            kCVPixelBufferPixelFormatTypeKey: bits.os,
//            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
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
        
        let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8, //bits.rawValue,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                      space: rgbColorSpace,
                                      bitmapInfo: swizzel || bits.os == kCVPixelFormatType_64ARGB ? CGImageAlphaInfo.premultipliedFirst.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)
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
        case stretch
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
        case .stretch:
            #if os(macOS)
            frame = CGRect(origin: .zero, size: CGSize(width: size.width / 2.0, height: size.height / 2.0))
            #else
            frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
            #endif
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
    
    /// Check out makeTextureFromCache first...
    public static func makeTexture(from pixelBuffer: CVPixelBuffer, with commandBuffer: MTLCommandBuffer, force8bit: Bool = false, on metalDevice: MTLDevice) throws -> MTLTexture {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let image = cgImage else {
            throw TextureError.makeTexture("Pixel Buffer to Metal Texture Converion Faied with VTCreate method.")
        }
        return try makeTexture(from: image, with: commandBuffer, on: metalDevice)
    }
    
    public static func makeTexture(from ciImage: CIImage, at size: CGSize, colorSpace: CGColorSpace, bits: Bits, with commandBuffer: MTLCommandBuffer, on metalDevice: MTLDevice, vFlip: Bool = true) throws -> MTLTexture {
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
    
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    public static func makeTextureViaRawData<T: ChannelType>(from pixelBuffer: CVPixelBuffer, bits: Bits, on metalDevice: MTLDevice, sourceZero: T, sourceOne: T, normalize: Bool = false, invertGreen: Bool = false) throws -> MTLTexture {
        
        #if os(macOS)
        var bits: Bits = bits
        if bits == ._16 {
            bits = ._8
        }
        #endif
        
        let channelCount: Int
        switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
        case 1278226534: // OneComponent32Float
            channelCount = 1
        case 843264102: // TwoComponent32Float
            channelCount = 2
        default:
            channelCount = 4
        }
        
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        let width: Int = Int(size.width)
        let height: Int = Int(size.height)
        
        let count: Int = width * height * channelCount
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw TextureError.makeTexture("CVPixelBufferGetBaseAddress Failed")
        }
        
        let buffer = baseAddress.assumingMemoryBound(to: T.self)

        func channel(at index: Int) -> Any? {
            guard index < count else {
                fatalError("Pixel Channel Index out of Range")
            }
            let channel: T = buffer[index]
            switch bits {
            case ._8:
                if normalize {
                    switch T.bits {
                    case ._8:
                        return UInt8(128 + min(channel as! UInt8, 127))
                    case ._32:
                        var value = UInt8(min(max((0.5 + (channel as! Float)) * 255, 0), 255))
                        if invertGreen {
                            if index % channelCount == 1 {
                                value = 255 - value
                            }
                        }
                        return value
                    default:
                        return nil
                    }
                } else {
                    return channel.as8bit
                }
            case ._16:
                if normalize {
                    return nil
                }
                switch T.bits {
                case ._8:
                    #if !os(macOS)
                    return Float16(Int(channel as! UInt8)) / Float16(255.0)
                    #endif
                    return nil
                case ._16:
                    return channel
                case ._32:
                    #if !os(macOS)
                    return Float16(channel as! Float)
                    #endif
                    return nil
                default:
                    return nil
                }
            case ._32:
                if normalize {
                    return nil
                }
                return channel.as32bit
            default:
                return nil
            }
        }
        
        var targetZero: Any {
            switch bits {
            case ._8:
                return UInt8(0)
            case ._16:
                #if !os(macOS)
                return Float16(0.0)
                #endif
                return 0.0
            case ._32:
                return Float(0.0)
            default:
                return 0.0
            }
        }
        
        var targetOne: Any {
            switch bits {
            case ._8:
                return UInt8(255)
            case ._16:
                #if !os(macOS)
                return Float16(1.0)
                #endif
                return 1.0
            case ._32:
                return Float(1.0)
            default:
                return 1.0
            }
        }

        var channels8: [UInt8] = []
        #if !os(macOS)
        var channels16: [Float16] = []
        #endif
        var channels32: [Float] = []
        
        for y in 0..<height {
            for x in 0..<width {
                
                let index: Int = y * width * channelCount + x * channelCount
            
                let red = channel(at: index) ?? targetZero
                let green = channelCount >= 2 ? channel(at: index + 1) ?? targetZero : targetZero
                let blue = channelCount >= 3 ? channel(at: index + 2) ?? targetZero : targetZero
                let alpha = channelCount == 4 ? channel(at: index + 3) ?? targetZero : targetOne
                
                switch bits {
                case ._8:
                    channels8.append(contentsOf: [
                        blue as! UInt8,
                        green as! UInt8,
                        red as! UInt8,
                        alpha as! UInt8
                    ])
                case ._16:
                    #if !os(macOS)
                    channels16.append(contentsOf: [
                        blue as! Float16,
                        green as! Float16,
                        red as! Float16,
                        alpha as! Float16
                    ])
                    #else
                    break
                    #endif
                case ._32:
                    channels32.append(contentsOf: [
                        blue as! Float,
                        green as! Float,
                        red as! Float,
                        alpha as! Float
                    ])
                default:
                    break
                }
                
            }
        }
        
        let texture = try emptyTexture(size: size,
                                       bits: bits,
                                       on: metalDevice,
                                       write: false)
        
        let bytesPerChannel: Int = bits.rawValue / 8
        let bytesPerRow = width * 4 * bytesPerChannel
        
        let mtlOrigin = MTLOrigin(x: 0, y: 0, z: 0)
        let mtlSize = MTLSize(width: width,
                              height: height,
                              depth: 1)
        let region = MTLRegion(origin: mtlOrigin,
                               size: mtlSize)
        
        switch bits {
        case ._8:
            texture.replace(region: region, mipmapLevel: 0, withBytes: channels8, bytesPerRow: bytesPerRow)
        case ._16:
            #if !os(macOS)
            texture.replace(region: region, mipmapLevel: 0, withBytes: channels16, bytesPerRow: bytesPerRow)
            #else
            throw TextureError.copy("Bits (16) Not Supported on macOS")
            #endif
        case ._32:
            texture.replace(region: region, mipmapLevel: 0, withBytes: channels32, bytesPerRow: bytesPerRow)
        default:
            throw TextureError.copy("Bits (\(bits.rawValue)) Not Supported")
        }
        
        return texture
    }
    
    public static func makeTextureFromCache(from pixelBuffer: CVPixelBuffer, bits: Bits, in textureCache: CVMetalTextureCache) throws -> MTLTexture {
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let channelCount = bytesPerRow / width
        let pixelFormat: MTLPixelFormat
        switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
        case 1278226534: // OneComponent32Float
            pixelFormat = Bits._32.monochromePixelFormat
        case 843264102: // TwoComponent32Float
            pixelFormat = bits.pixelFormat
        default:
            switch channelCount {
            case 4: pixelFormat = bits.pixelFormat
            case 2: pixelFormat = Bits._16.monochromePixelFormat
            default: pixelFormat = bits.pixelFormat
            }
        }
        
        var imageTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, pixelFormat, width, height, 0, &imageTexture)
        
        guard let imageTexture = imageTexture,
              let texture = CVMetalTextureGetTexture(imageTexture),
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
    
    public static func emptyTexture(size: CGSize, bits: Bits, on metalDevice: MTLDevice, write: Bool = false/*, makeIOSurface: Bool = false*/) throws -> MTLTexture {
        
        guard size.width > 0 && size.height > 0 else { throw TextureError.emptyFail }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: bits.pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: true)
        
        descriptor.usage = MTLTextureUsage(rawValue: write ? (MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue) : (MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue))
        
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.emptyFail
        }
        
        return texture
    }
    
    public static func emptyTextureCube(size: Int, bits: Bits, on metalDevice: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: bits.pixelFormat, size: size, mipmapped: false)
        descriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TextureError.emptyFail
        }
        return texture
    }
    
    public static func emptyTexture3D(at resolution: Resolution3D, bits: Bits, on metalDevice: MTLDevice) throws -> MTLTexture {
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
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
        guard let bits = Bits.bits(for: firstTexture.pixelFormat) else {
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
        guard let bits = Bits.bits(for: firstTexture.pixelFormat) else {
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
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
    
    public static func sampleBuffer(texture: MTLTexture, colorSpace: CGColorSpace, bits: Bits) -> CMSampleBuffer? {
        
        let size = CGSize(width: texture.width, height: texture.height)
        guard let pixelBuffer: CVPixelBuffer = try? Texture.pixelBuffer(from: texture, at: size, colorSpace: colorSpace, bits: bits) else {
            return nil
        }
        
        return sampleBuffer(pixelBuffer: pixelBuffer)
    }
    
    public static func sampleBuffer(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = .zero
        info.duration = .zero
        info.decodeTimeStamp = .zero
        
        var formatDesc: CMFormatDescription!
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDesc)
        guard formatDesc != nil else {
            return nil
        }
        
        var sampleBuffer: CMSampleBuffer?
        
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer,
                                                 formatDescription: formatDesc,
                                                 sampleTiming: &info,
                                                 sampleBufferOut: &sampleBuffer);
        return sampleBuffer
        
    }
    
    public static func cgImage(from texture: MTLTexture, colorSpace: CGColorSpace, bits: Bits, vFlip: Bool = true) -> CGImage? {
        guard let ciImage: CIImage = ciImage(from: texture, colorSpace: colorSpace) else { return nil }
        let size = CGSize(width: texture.width, height: texture.height)
        guard let cgImage: CGImage = cgImage(from: ciImage, at: size, colorSpace: colorSpace, bits: bits, vFlip: vFlip) else { return nil }
        return cgImage
    }
    
    public static func ciImage(from texture: MTLTexture, colorSpace: CGColorSpace) -> CIImage? {
        CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace])
    }
    
    public static func cgImage(from ciImage: CIImage, at size: CGSize, colorSpace: CGColorSpace, bits: Bits, vFlip: Bool = true) -> CGImage? {
        guard let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent, format: bits.ci, colorSpace: colorSpace) else { return nil }
        #if os(iOS) || os(tvOS)
        let flip: Bool = vFlip
        #elseif os(macOS)
        let flip: Bool = true
        #endif
        if flip {
            guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: bits.rawValue, bytesPerRow: 4 * Int(size.width) * (bits.rawValue / 8), space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
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
    
    public static func image(from ciImage: CIImage) -> _Image? {
        #if os(macOS)
        guard let colorSpace = ciImage.colorSpace else { return nil }
        guard let cgImage = cgImage(from: ciImage, at: ciImage.extent.size, colorSpace: colorSpace, bits: ._8) else { return nil }
        return NSImage(cgImage: cgImage, size: ciImage.extent.size)
        #else
        return UIImage(ciImage: ciImage)
        #endif
    }
    
    public static func image(from pixelBuffer: CVPixelBuffer) -> _Image? {
        guard let cgImage = cgImage(from: pixelBuffer) else { return nil }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: size)
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
    
    public static func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = ciImage(from: pixelBuffer)
        return ciImage.cgImage
    }
    
    public static func ciImage(from pixelBuffer: CVPixelBuffer) -> CIImage {
        CIImage(cvImageBuffer: pixelBuffer)
    }
    
    public static func ciImage(from image: _Image) -> CIImage? {
        #if os(macOS)
        guard let data = image.tiffRepresentation else { return nil }
        return CIImage(data: data)
        #else
        return CIImage(image: image)
        #endif
    }

    public static func image(from cgImage: CGImage, at size: CGSize) -> _Image {
        #if os(iOS) || os(tvOS)
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up) // .downMirrored
        #elseif os(macOS)
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }

    public static func image(from texture: MTLTexture, colorSpace: CGColorSpace, vFlip: Bool = true) -> _Image? {
        let size = CGSize(width: texture.width, height: texture.height)
        guard let ciImage = ciImage(from: texture, colorSpace: colorSpace) else { return nil }
        guard let bits = Bits.bits(for: texture.pixelFormat) else { return nil }
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
    
    public static func pixelBuffer(from image: _Image, colorSpace: CGColorSpace, bits: Bits) throws -> CVPixelBuffer {
        #if os(iOS) || os(tvOS)
        guard let cgImage = image.cgImage else { throw PixelBufferError.cgImage }
        #elseif os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw PixelBufferError.cgImage }
        #endif
        return try pixelBuffer(from: cgImage, colorSpace: colorSpace, bits: bits)
    }
    
    public static func pixelBuffer(from cgImage: CGImage, colorSpace: CGColorSpace, bits: Bits) throws -> CVPixelBuffer {
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
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw PixelBufferError.status("Context failed to be created.")
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return pixelBuffer
    }
    
    public static func pixelBuffer(from texture: MTLTexture, at size: CGSize, colorSpace: CGColorSpace, bits: Bits, vFlip: Bool = true) throws -> CVPixelBuffer {
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
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
    
    #if !os(macOS) && !targetEnvironment(macCatalyst)
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    public static func raw16(texture: MTLTexture) throws -> [Float16] {
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 16 - Texture bits out of range.")
        }
        guard bits == ._16 else {
            throw TextureError.raw("Raw 16 - To access this data, the texture needs to be in 16 bit.")
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float16>(repeating: -1.0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float16>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    public static func raw3d16(texture: MTLTexture) throws -> [Float16] {
        guard let bits = Bits.bits(for: texture.pixelFormat) else {
            throw TextureError.raw("Raw 16 - Texture bits out of range.")
        }
        guard bits == ._16 else {
            throw TextureError.raw("Raw 16 - To access this data, the texture needs to be in 16 bit.")
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<Float16>(repeating: -1.0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float16>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<Float16>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    #endif
    
//    public static func rawCopy3d16(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [Float] {
//        guard let bits = Bits.bits(for: texture.pixelFormat) else {
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
    
    public static func raw32(texture: MTLTexture) throws -> [Float] {
//        guard let bits = Bits.bits(for: texture.pixelFormat) else {
//            throw TextureError.raw("Raw 32 - Texture bits out of range.")
//        }
//        guard bits == ._32 else {
//            throw TextureError.raw("Raw 32 - To access this data, the texture needs to be in 32 bit.")
//        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float>(repeating: -1.0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    public static func raw3d32(texture: MTLTexture) throws -> [Float] {
//        guard let bits = Bits.bits(for: texture.pixelFormat) else {
//            throw TextureError.raw("Raw 32 - Texture bits out of range.")
//        }
//        guard bits == ._32 else {
//            throw TextureError.raw("Raw 32 - To access this data, the texture needs to be in 32 bit.")
//        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<Float>(repeating: -1.0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<Float>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    public static func rawNormalized(texture: MTLTexture, bits: Bits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._10:
            throw TextureError.raw("Raw 10 - Not supported.")
        case ._16:
            #if !os(macOS) && !targetEnvironment(macCatalyst)
            if #available(macOS 11.0, *) {
                if #available(tvOS 14.0, *) {
                    if #available(iOS 14.0, *) {
                        raw = try raw16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
                    } else {
                        raw = []
                    }
                } else {
                    raw = []
                }
            } else {
                raw = []
            }
            #else
            raw = []
            #endif
        case ._32:
            raw = try raw32(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
        }
        return raw
    }
    
    public static func rawNormalizedCopy(texture: MTLTexture, bits: Bits, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [CGFloat] {
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
    
    public static func rawNormalized3d(texture: MTLTexture, bits: Bits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw3d8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._10:
            throw TextureError.raw("Raw 10 - Not supported.")
        case ._16:
            #if !os(macOS) && !targetEnvironment(macCatalyst)
            if #available(macOS 11.0, *) {
                if #available(tvOS 14.0, *) {
                    if #available(iOS 14.0, *) {
                        raw = try raw3d16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
                    } else {
                        raw = []
                    }
                } else {
                    raw = []
                }
            } else {
                raw = []
            }
            #else
            raw = [-1.0]
            #endif
        case ._32:
            raw = try raw3d32(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
        }
        return raw
    }
    
    public static func rawNormalizedCopy3d(texture: MTLTexture, bits: Bits, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [CGFloat] {
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
