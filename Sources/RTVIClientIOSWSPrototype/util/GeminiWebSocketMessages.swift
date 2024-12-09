// MARK: - Inbound

import Foundation

struct ModelAudioMessage: Decodable {
    var serverContent: ServerContent
    
    func audioBytes() -> Data? {
        guard let part = serverContent.modelTurn.parts.first else {
            return nil
        }
        return Data(base64Encoded: part.inlineData.data)
    }
    
    struct ServerContent: Decodable {
        var modelTurn: ModelTurn
        
        struct ModelTurn: Decodable {
            var parts: [Part]
            
            struct Part: Decodable {
                var inlineData: InlineData
                
                struct InlineData: Decodable {
                    var data: String
                }
            }
        }
    }
}

// MARK: - Outbound

struct SetupMessage: Encodable {
    var setup: Setup
    
    struct Setup: Encodable {
        var model: String
    }
    
    init(model: String) {
        self.setup = .init(model: model)
    }
}

struct TextInputMessage: Encodable {
    var clientContent: ClientContent
    
    struct ClientContent: Encodable {
        var turns: [Turn]
        var turnComplete = true
        
        struct Turn: Encodable {
            var role = "USER"
            var parts: [Text]
            
            struct Text: Encodable {
                var text: String
            }
        }
    }
    
    init(text: String) {
        self.clientContent = .init(
            turns: [
                .init(parts: [.init(text: text)])
            ]
        )
    }
}
