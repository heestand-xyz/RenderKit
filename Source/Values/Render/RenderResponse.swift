//
//  Created by Anton Heestand on 2021-03-15.
//

import Foundation
import Metal

public struct RenderResponse {
    public let id: UUID
    public let startFrameIndex: Int
    public let finalFrameIndex: Int
    public let renderTime: Double
    public let texture: MTLTexture
}
