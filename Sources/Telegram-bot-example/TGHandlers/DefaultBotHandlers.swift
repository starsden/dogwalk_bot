import Vapor
import TelegramVaporBot

final class DefaultBotHandlers {
    private static var userStates: [Int64: BookingState] = [:]
    private static let adminUserId: Int64 = 6627628549
    private static var bookingA: [Int64: Int64] = [:]

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandstatkHandler(app: app, connection: connection)
        await bookHandler(app: app, connection: connection)
        await startHandler(app: app, connection: connection)
    }

    private static func startHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/start", "/dog"]) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Забронировать время", callbackData: "time"), .init(text: "Узнать подробнее", callbackData: "moreinf")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Доброго времени суток!👋 \nЯ помогу вам забронировать время для прогулки с вашей собакой🐶",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })
    }

    private static func bookHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "time") { update, bot in
            guard let userId = update.callbackQuery?.from.id else { return }
            userStates[userId] = .nameus
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как вас зовут?")
            try await bot.sendMessage(params: params)
        })

        await connection.dispatcher.add(TGMessageHandler(filters: .all) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            guard let text = update.message?.text else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Простите, я понимаю только слова( \nУ меня же лапки!")
                try await bot.sendMessage(params: params)
                return
            }

            guard let state = userStates[userId] else { return }
            
            switch state {
            case .nameus:
                userStates[userId] = .dogname(userName: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как зовут вашу собаку?")
                try await bot.sendMessage(params: params)
            case .dogname(let userName):
                userStates[userId] = .dogclass(userName: userName, dogName: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Какой породы собака?")
                try await bot.sendMessage(params: params)
            case .dogclass(let userName, let dogName):
                userStates[userId] = .time(userName: userName, dogName: dogName, dogClass: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Когда нужно забрать \(dogName)?")
                try await bot.sendMessage(params: params)
            case .time(let userName, let dogName, let dogClass):
                userStates[userId] = .loca(userName: userName, dogName: dogName, dogClass: dogClass, time: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Откуда забрать \(dogName)?")
                try await bot.sendMessage(params: params)
            case .loca(let userName, let dogName, let dogClass, let time):
                userStates[userId] = .phnum(userName: userName, dogName: dogName, dogClass: dogClass, time: time, loca: text)
                let buttons: [[TGKeyboardButton]] = [
                    [.init(text: "Отправить свой номер", requestContact: true)]
                ]
                let keyboard: TGReplyKeyboardMarkup = .init(keyboard: buttons, oneTimeKeyboard: true)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как с вами связаться?", replyMarkup: .replyKeyboardMarkup(keyboard))
                try await bot.sendMessage(params: params)
            case .phnum(let userName, let dogName, let dogClass, let time, let loca):
                let phnum: String
                if let contact = update.message?.contact {
                    phnum = contact.phoneNumber ?? ""
                } else {
                    phnum = text
                }
                let booking = Booking(userId: userId, userName: userName, dogName: dogName, dogClass: dogClass, time: time, phnum: phnum, loca: loca)
                bookingA[userId] = adminUserId
                try await sendBookingToAdmin(booking: booking, bot: bot, app: app)

                userStates.removeValue(forKey: userId)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Бронирование успешно завершено❤️ \nСпасибо!")
                try await bot.sendMessage(params: params)
            }
        })

        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "moreinf") { update, bot in
            guard let userId = update.callbackQuery?.from.id, let messageId = update.callbackQuery?.message?.messageId else { return }
            try await bot.deleteMessage(params: .init(chatId: .chat(userId), messageId: messageId))
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Вернуться", callbackData: "goback")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Гуляю всех собак, от больших до маленьких. Люблю всех🐕 \n\n400 рублей  - 40 минут", replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })

        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "goback") { update, bot in
            guard let userId = update.callbackQuery?.from.id, let messageId = update.callbackQuery?.message?.messageId else { return }
            try await bot.deleteMessage(params: .init(chatId: .chat(userId), messageId: messageId))
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Забронировать время", callbackData: "time"), .init(text: "Узнать подробнее", callbackData: "moreinf")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Доброго времени суток!👋 \nЯ помогу вам забронировать время для прогулки с вашей собакой🐶",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })

        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "сancelbook") { update, bot in
            guard let adminId = update.callbackQuery?.from.id, adminId == adminUserId else { return }
            guard let userId = bookingA.first(where: { $0.value == adminUserId })?.key else { return }
            
            let userParams: TGSendMessageParams = .init(chatId: .chat(userId), text: "Ваше бронирование было отменено по решению администратора😢 \n\nВы можете связаться с ним для выяснения обстоятельств: @hahaaka ")
            try await bot.sendMessage(params: userParams)
            
            bookingA.removeValue(forKey: userId)
        })
    }

    private static func sendBookingToAdmin(booking: Booking, bot: TGBotPrtcl, app: Vapor.Application) async throws {
        let message = """
        Новое бронирование✅:
        \nID пользователя: \(booking.userId)
        Имя хозяина: \(booking.userName)
        Имя собаки: \(booking.dogName)
        Порода собаки: \(booking.dogClass)
        Время: \(booking.time)
        Адрес: \(booking.loca)
        Контакты: \(booking.phnum)
        """
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "❌Отказаться❌", callbackData: "сancelbook")]
        ]
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let params: TGSendMessageParams = .init(chatId: .chat(adminUserId), text: message, replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await bot.sendMessage(params: params)
        

        let payload = BookingPayload(userId: booking.userId, userName: booking.userName, dogName: booking.dogName, dogClass: booking.dogClass, time: booking.time, phnum: booking.phnum, loca: booking.loca)
        
        // Convert the payload to JSON and print it to the console
        let jsonData = try JSONEncoder().encode(payload)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("JSON Payload: \(jsonString)")
        }

        try await sendBookingToServer(payload: payload, app: app)
    }

    private static func sendBookingToServer(payload: BookingPayload, app: Vapor.Application) async throws {
        let client = app.client
        let url = URI(string: "http://62.84.115.125:5000/book")
        
        do {
            let response = try await client.post(url, headers: ["Content-Type": "application/json"]) { req in
                try req.content.encode(payload)
            }
            
            guard response.status == .created else {
                print("Ошибка при отправке данных о бронировании: \(response.status)")
                return
            }
            
            print("Данные о бронировании успешно отправлены")
        } catch {
            print("Произошла ошибка: \(error.localizedDescription)")
        }
    }

    private struct BookingPayload: Content {
        let userId: Int64
        let userName: String
        let dogName: String
        let dogClass: String
        let time: String
        let phnum: String
        let loca: String
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case userName = "user_name"
            case dogName = "dog_name"
            case dogClass = "dog_class"
            case time
            case phnum
            case loca
        }
    }
}

private func commandstatkHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
    await connection.dispatcher.add(TGCommandHandler(commands: ["/http"]) { update, bot in
        try await update.message?.reply(text: "status 200", bot: bot)
    })
}

enum BookingState {
    case nameus
    case dogname(userName: String)
    case dogclass(userName: String, dogName: String)
    case time(userName: String, dogName: String, dogClass: String)
    case loca(userName: String, dogName: String, dogClass: String, time: String)
    case phnum(userName: String, dogName: String, dogClass: String, time: String, loca: String)
}

struct Booking {
    let userId: Int64
    let userName: String
    let dogName: String
    let dogClass: String
    let time: String
    let phnum: String
    let loca: String
}
