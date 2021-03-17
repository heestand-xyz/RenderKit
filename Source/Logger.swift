//
//  PixelKitLog.swift
//  PixelKit
//
//  Created by Heestand XYZ on 2018-08-16.
//  Open Source - MIT License
//

import Foundation

public protocol LoggerDelegate {
    func loggerFrameIndex() -> Int
    func loggerLinkIndex(of node: NODE) -> Int?
}

public class Logger {
    
    public var delegate: LoggerDelegate?
    
    let prefix: String
    
    public var active: Bool = true
    public var silent: Bool = false
    public var level: LogLevel = .default
    public var source: Bool = false
    public var loopLimitActive = true
    public var loopLimitFrameCount = 30
    public var highResWarnings = true
    var loopLimitIndicated = false

    public var time = false
    public var padding = false
    public var extra = false

    public var dynamicShaderCode = false

    private var callbacks: [(String, Log) -> ()] = []
    
    public struct Log {
        public let prefix: String
        public let level: LogLevel
        public let category: LogCategory?
        public let time: Date
        public let codeRef: CodeRef
        public let nodeRef: NODERef?
        public let message: String
        public let error: Error?
        public let loop: Bool
    }
    
    public struct NODERef {
        public let id: UUID
        public let name: String?
        public let type: String
        public let linkIndex: Int?
        init(for node: NODE, linkIndex: Int?) {
            id = node.id
            name = node.name
            type = String(String(describing: node).split(separator: ".").last ?? "")
            self.linkIndex = linkIndex
        }
    }
    
    public struct CodeRef {
        public let file: String
        public let function: String
        public let line: Int
    }
    
    public enum LogLevel: String {
        case fatal = "FATAL"
        case error = "ERROR"
        case warning = "WARNING"
        case info = "INFO"
        case detail = "DETAIL"
        case debug = "DEBUG"
        static let `default`: LogLevel = .info
        public var index: Int {
            switch self {
            case .fatal: return 0
            case .error: return 1
            case .warning: return 2
            case .info: return 3
            case .detail: return 4
            case .debug: return 5
            }
        }
    }
    
    public enum LogCategory: String {
        case pixelKit = "PixelKit"
        case render = "Render"
        case texture = "Texture"
        case resource = "Resource"
        case generator = "Generator"
        case effect = "Effect"
        case connection = "Connection"
        case view = "View"
        case resolution = "Resolution"
        case fileIO = "File IO"
        case metal = "Metal"
    }
    
    public func logAll(padding: Bool = false, limit: Bool = false) {
        level = .detail
        loopLimitActive = limit
        self.padding = padding
    }
    
    public func logDebug(padding: Bool = false, limit: Bool = false) {
        logAll(padding: padding, limit: limit)
        level = .debug
        source = true
        time = true
    }
    
    public func logLess() {
        level = .error
    }
    
    public init(name: String) {
        prefix = name
    }
    
    public func log(prefix: String? = nil, node: NODE? = nil, _ level: LogLevel, _ category: LogCategory?, _ message: String, loop: Bool = false, clean: Bool = false, e error: Error? = nil, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        
        guard delegate != nil else {
            print("Logger delegate not set...")
            return
        }
        
        let prefix = prefix ?? self.prefix
        
        let time = Date()
        let nodeRef = node != nil ? NODERef(for: node!, linkIndex: delegate!.loggerLinkIndex(of: node!)) : nil
        let codeRef = CodeRef(file: file, function: function, line: line)
        
        let log = Log(prefix: prefix, level: level, category: category, time: time, codeRef: codeRef, nodeRef: nodeRef, message: message, error: error, loop: loop)
        
        guard level != .fatal else {
            callbacks.forEach({ $0(format(log: log), log) })
            fatalError(formatClean(log: log))
        }
        
        guard active && level.index <= self.level.index else {
            return
        }
        
        if loop && loopLimitActive && delegate!.loggerFrameIndex() > loopLimitFrameCount {
            if !loopLimitIndicated {
                print("\(prefix) running...")
                loopLimitIndicated = true
            }
            return
        }
        
        if clean {
            callbacks.forEach({ $0(format(log: log), log) })
            if !silent { print(formatClean(log: log)) }
            return
        }
        
        #if !DEBUG
        if level == .debug {
            return
        }
        #endif
        
        callbacks.forEach({ $0(format(log: log), log) })
        if !silent { print(format(log: log)) }

    }
    
    public func formatClean(log: Log) -> String {
        var cleanLog = "\(log.prefix) "
        if log.nodeRef != nil {
            cleanLog += "\(log.nodeRef!.type) "
        }
        cleanLog += log.message
        if let e = log.error {
            cleanLog += " Error: \(e)"
        }
        return cleanLog
    }
    
    public func format(log: Log) -> String {
        
        var logList: [String] = []
        
        var padding = 0
        
        logList.append(log.prefix)
        
        let frameIndex = delegate!.loggerFrameIndex()
        logList.append("#\(frameIndex < 10 ? "0" : "")\(frameIndex)")
        
        var tc = 0
        if time {
            let df = DateFormatter()
            let f = "HH:mm:ss.SSS"
            tc = f.count + 2
            df.dateFormat = f
            let ts = df.string(from: log.time)
            logList.append(ts)
        }
        
        logList.append(log.level.rawValue)
        
        var ext = 0
        if extra {
            ext += 5
            if log.level == .warning {
                logList.append("⚠️"); ext -= 1
            } else if log.level == .error {
                logList.append("❌"); ext -= 1
            }
        }
        
        if self.padding { padding += 30; logList.append(spaces(tc + ext + padding - logLength(logList))) }
        
        if let nodeRef = log.nodeRef {
            if let nr = nodeRef.linkIndex {
                logList.append("[\(nr + 1)]")
            }
            logList.append(nodeRef.type)
        }
        
        if self.padding { padding += 20; logList.append(spaces(tc + ext + padding - logLength(logList))) }
        
        if let nodeRef = log.nodeRef {
            if let nodeName = nodeRef.name {
                logList.append("\"\(nodeName)\"")
            }
        }
        
        if self.padding { padding += 20; logList.append(spaces(tc + ext + padding - logLength(logList))) }
        
        if let c = log.category {
            logList.append(c.rawValue)
        }
        
        if self.padding { padding += 20; logList.append(spaces(tc + ext + padding - logLength(logList))) }
        else { logList.append(">>>") }
        
        logList.append(log.message)
        
        if let e = log.error {
            logList.append("x>> Error: \(e) (\"\(e.localizedDescription)\")")
        }
        
        if source {
            if self.padding { padding += 50; logList.append(spaces(tc + ext + padding - logLength(logList))) }
            else { logList.append("<<<") }
            let fileName = log.codeRef.file.split(separator: "/").last!
            logList.append("\(fileName):\(log.codeRef.function):\(log.codeRef.line)")
        }
        
        var log = ""
        for (i, subLog) in logList.enumerated() {
            if i > 0 { log += " " }
            log += subLog
        }
        
        return log
        
    }
    
    func logLength(_ logList: [String]) -> Int {
        var length = -1
        for log in logList {
            length += log.count + 1
        }
        return length
    }
    
    func spaces(_ count: Int) -> String {
        guard count > 0 else { return "" }
        var spaces = ""
        for _ in 0..<count {
            spaces += " "
        }
        return spaces
    }
    
    public func listen(_ callback: @escaping (String, Log) -> ()) {
        callbacks.append(callback)
    }
    
}
