//
//  Created by Anton Heestand on 2021-03-15.
//

import Foundation

public struct RenderPack {
    public var id: UUID { request.id }
    public let request: RenderRequest
    public let response: RenderResponse
    init(request: RenderRequest, response: RenderResponse) {
        precondition(request.id == response.id)
        self.request = request
        self.response = response
    }
}
public typealias RenderResult = Result<RenderPack, Error>
public typealias RenderCompletionHandler = (RenderResult) -> ()
