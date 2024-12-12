// MARK: - Inbound

import Foundation

// enums just for namespacing
enum WebSocketMessages {
    
    // MARK: - Inbound
    
    enum Inbound {
        struct AudioOutput: Decodable {
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
    }
    
    // MARK: - Outbound
    
    enum Outbound {
        struct Setup: Encodable {
            var setup: Setup
            
            struct Setup: Encodable {
                var model: String
            }
            
            init(model: String) {
                self.setup = .init(model: model)
            }
        }

        struct TextInput: Encodable {
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
        
        struct AudioInput: Encodable {
            var realtimeInput: RealtimeInput
            
            struct RealtimeInput: Encodable {
                var mediaChunks: [MediaChunk]
                
                struct MediaChunk: Encodable {
                    var mimeType: String
                    var data: String
                }
            }
            
            init(audio: Data) {
                realtimeInput = .init(
                    mediaChunks: [
                        .init(
                            mimeType: "audio/pcm;rate=\(Int(AudioCommon.format.sampleRate))",
//                            data: audio.base64EncodedString()
                            // Hm...this avoids the WebSocket 1007 disconnect (which happens with the above), but clearly this is junk/garbled audio. The model keeps thinking we're interrupting with nonsense.
                            data: String(data: audio.base64EncodedData(), encoding: .utf8)!
                        )
                    ]
                )
            }
        }
    }
}
