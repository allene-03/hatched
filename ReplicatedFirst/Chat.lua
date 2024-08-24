local Chat = game:GetService("Chat")

Chat:RegisterChatCallback(Enum.ChatCallbackType.OnCreatingChatWindow, function()
	return {
		ClassicChatEnabled = true,
		BubbleChatEnabled = true,
		
		DefaultFont = Enum.Font.FredokaOne,
		ChatBarFont = Enum.Font.FredokaOne,
	}
end)

-- https://devforum.roblox.com/t/changing-chat-type-and-other-chat-settings-without-forking/313614
-- https://devforum.roblox.com/t/the-big-bubble-chat-rework/819483
