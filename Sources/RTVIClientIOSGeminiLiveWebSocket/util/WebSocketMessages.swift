// MARK: - Inbound

import Foundation
import RTVIClientIOS

// enums just for namespacing
enum WebSocketMessages {
    
    // MARK: - Inbound
    
    enum Inbound {
        struct SetupComplete: Decodable {
            var setupComplete: EmptyObject
            
            struct EmptyObject: Decodable {}
        }
        
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
        
        struct Interrupted: Decodable {
            var serverContent: ServerContent
            
            struct ServerContent: Decodable {
                var interrupted = true
            }
        }
    }
    
    // MARK: - Outbound
    
    enum Outbound {
        struct Setup: Encodable {
            var setup: Setup
            
            struct Setup: Encodable {
                var model: String
                var generationConfig: Value?
            }
            
            init(model: String, generationConfig: Value?) {
                self.setup = .init(model: model, generationConfig: generationConfig)
            }
        }

        struct TextInput: Encodable {
            var clientContent: ClientContent
            
            struct ClientContent: Encodable {
                var turns: [Turn]
                var turnComplete = true
                
                struct Turn: Encodable {
                    var role: String
                    var parts: [Text]
                    
                    struct Text: Encodable {
                        var text: String
                    }
                }
            }
            
            init(text: String, role: String) {
                self.clientContent = .init(
                    turns: [
                        .init(role: role == "user" ? "USER" : "SYSTEM", parts: [.init(text: text)])
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
                            data: audio.base64EncodedString()
                        )
                    ]
                )
            }
        }
    }
}
