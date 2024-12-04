import Foundation

struct DailyTransportAuthBundle: Codable {
    let roomUrl: String
    let token: String?
    
    enum CodingKeys: String, CodingKey {
        case roomUrl = "room_url"
        case token
    }
}
