import RTVIClientIOS

extension RTVIClientOptions {
    var webSocketConnectionOptions: GeminiLiveWebSocketConnection.Options {
        let config = config ?? params.config
        return .init(
            apiKey: config.apiKey ?? "",
            initialMessages: config.initialMessages,
            generationConfig: config.generationConfig
        )
    }
}

extension [ServiceConfig] {
    var apiKey: String? {
        let apiKeyOption = llmConfig?.options.first { $0.name == "api_key" }
        if case let .string(apiKey) = apiKeyOption?.value {
            return apiKey
        }
        return nil
    }
    
    var initialMessages: [WebSocketMessages.Outbound.TextInput] {
        let initialMessagesKeyOption = llmConfig?.options.first { $0.name == "initial_messages" }
        return initialMessagesKeyOption?.value.toTextInputWebSocketMessagesArray() ?? []
    }
    
    var generationConfig: Value? {
        llmConfig?.options.first { $0.name == "generation_config" }?.value
    }
    
    var llmConfig: ServiceConfig? {
        first { $0.service == "llm" }
    }
}

extension Value {
    // Tries to parse this options Value as an array of LLM messages, converted to WebSocketMessages.Outbound.TextInput
    func toTextInputWebSocketMessagesArray() -> [WebSocketMessages.Outbound.TextInput] {
        var messages: [WebSocketMessages.Outbound.TextInput] = []
        if case let .array(messageValues) = self {
            for messageValue in messageValues {
                if case let .object(messageObject) = messageValue {
                    let roleValue = messageObject["role"]
                    let contentValue = messageObject["content"]
                    if case let .string(role) = roleValue {
                        if case let .string(content) = contentValue {
                            messages.append(.init(text: content, role: role))
                        }
                    }
                }
            }
        }
        return messages
    }
}
