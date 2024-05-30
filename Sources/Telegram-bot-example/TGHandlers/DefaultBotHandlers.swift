import Vapor
import TelegramVaporBot

final class DefaultBotHandlers {
    private static var userStates: [Int64: BookingState] = [:]

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandPukHandler(app: app, connection: connection)
        await buttonsActionHandler(app: app, connection: connection)
        await startHandler(app: app, connection: connection)
    }
    
    private static func startHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/start"]) { update, bot in
            guard let userId = update.message?.from?.id else { fatalError("user id not found") }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Забронировать время", callbackData: "time"), .init(text: "Узнать подробнее", callbackData: "moreinf")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Доброго времени суток! \nЯ помогу вам забронировать время для прогулки с вашей собакой.",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })
    }

    private static func buttonsActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "time") { update, bot in
            guard let userId = update.callbackQuery?.from.id else { fatalError("user id not found") }
            userStates[userId] = .askingName
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как вас зовут?")
            try await bot.sendMessage(params: params)
        })

        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "moreinf") { update, bot in
            TGBot.log.info("moreinf")
            let params: TGAnswerCallbackQueryParams = .init(callbackQueryId: update.callbackQuery?.id ?? "0",
                                                            text: update.callbackQuery?.data ?? "data not exist",
                                                            showAlert: nil,
                                                            url: nil,
                                                            cacheTime: nil)
            try await bot.answerCallbackQuery(params: params)
        })

        await connection.dispatcher.add(TGMessageHandler(filters: .all) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            guard let state = userStates[userId] else { return }

            switch state {
            case .askingName:
                userStates[userId] = .askingDogName(userName: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как зовут вашу собаку?")
                try await bot.sendMessage(params: params)
                
            case .askingDogName(let userName):
                userStates[userId] = .askingDogBreed(userName: userName, dogName: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Какой породы собака?")
                try await bot.sendMessage(params: params)
                
            case .askingDogBreed(let userName, let dogName):
                userStates[userId] = .askingPickupTime(userName: userName, dogName: dogName, dogBreed: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Когда нужно забрать \(dogName)?")
                try await bot.sendMessage(params: params)
                
            case .askingPickupTime(let userName, let dogName, let dogBreed):
                let pickupTime = update.message?.text ?? ""
                let booking = Booking(userName: userName, dogName: dogName, dogBreed: dogBreed, pickupTime: pickupTime)

                userStates.removeValue(forKey: userId)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Бронирование успешно завершено. Спасибо!")
                try await bot.sendMessage(params: params)
            }
        })
    }

    private static func commandPukHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/puk"]) { update, bot in
            try await update.message?.reply(text: "членус", bot: bot)
        })
    }
}

enum BookingState {
    case askingName
    case askingDogName(userName: String)
    case askingDogBreed(userName: String, dogName: String)
    case askingPickupTime(userName: String, dogName: String, dogBreed: String)
}

struct Booking {
    let userName: String
    let dogName: String
    let dogBreed: String
    let pickupTime: String
}
