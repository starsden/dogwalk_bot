import Vapor
import TelegramVaporBot

final class DefaultBotHandlers {
    private static var userStates: [Int64: BookingState] = [:]
    private static let adminUserId: Int64 = 6627628549
    private static var bookingA: [Int64: Int64] = [:]

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await booking(app: app, connection: connection)
        await startHandler(app: app, connection: connection)
        await SendHis(app: app, connection: connection)
    }

    private static func startHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/start", "/dog"]) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            app.logger.info("\(userId) запустил бота")
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Забронировать время", callbackData: "time"), .init(text: "Узнать подробнее", callbackData: "moreinf")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId),
                                                    text: "Привет!👋 \nМеня зовут Лея! \nЯ виртуальный пес, который поможет вам забронировать время для прогулки с вашим четвероногим другом!🐶\n\nНажав на кнопки ниже вы можете узнать подробнее о наших прогулках или забронировать время! \nГав-Гав!",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })
    }

    private static func booking(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "time") { update, bot in
            guard let userId = update.callbackQuery?.from.id else { return }
            app.logger.info("User \(userId) started booking")
            userStates[userId] = .nameus
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Начнем!❤️\nКак вас зовут?")
            try await bot.sendMessage(params: params)
        })

        await connection.dispatcher.add(TGMessageHandler(filters: .all) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            guard let text = update.message?.text else {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Простите, я понимаю только слова( \nУ меня же лапки!🐾")
                try await bot.sendMessage(params: params)
                app.logger.info("\(userId) отправил не текст")
                return
            }

            guard let state = userStates[userId] else { return }
            switch state {
            case .nameus:
                userStates[userId] = .dogname(userName: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как зовут вашего питомца?")
                try await bot.sendMessage(params: params)
            case .dogname(let userName):
                userStates[userId] = .dogclass(userName: userName, dogName: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Какое милое имя!🥹 \nА какой породы?")
                try await bot.sendMessage(params: params)
            case .dogclass(let userName, let dogName):
                userStates[userId] = .time(userName: userName, dogName: dogName, dogClass: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Когда нужно будет забрать \(dogName)?")
                try await bot.sendMessage(params: params)
            case .time(let userName, let dogName, let dogClass):
                userStates[userId] = .loca(userName: userName, dogName: dogName, dogClass: dogClass, time: text)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "А откуда забрать \(dogName)?")
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
                try await sendAdmin(booking: booking, bot: bot, app: app)

                userStates.removeValue(forKey: userId)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Бронирование успешно завершено❤️ \nСпасибо! ")
                try await bot.sendMessage(params: params)
            }
        })

        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "moreinf") { update, bot in
            guard let userId = update.callbackQuery?.from.id, let messageId = update.callbackQuery?.message?.messageId else { return }
            app.logger.info("\(userId) запросил информацию")
            try await bot.deleteMessage(params: .init(chatId: .chat(userId), messageId: messageId))
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Вернуться", callbackData: "goback")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Меня зовут Лея, и у меня есть хозяин! Зовут его Денис, он очень любит всех собак и с радостью выгуляет вашу собаку! \n1 час прогулки - 400 рублей. \nОстались вопросы? - @dabyt ", replyMarkup: .inlineKeyboardMarkup(keyboard))
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
                                                    text: "Привет!👋 \nМеня зовут Лея! \nЯ виртуальный пес, который поможет вам забронировать время для прогулки с вашим четвероногим другом!🐶\n\nНажав на кнопки ниже вы можете узнать подробнее о наших прогулках или забронировать время! \nГав-Гав!",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })

        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "сancelbook") { update, bot in
            guard let adminId = update.callbackQuery?.from.id, adminId == adminUserId else { return }
            guard let userId = bookingA.first(where: { $0.value == adminUserId })?.key else { return }
            app.logger.info("Админ отклонил заявку на прогулку \(userId)")
            
            let userParams: TGSendMessageParams = .init(chatId: .chat(userId), text: "Гав-Гав! \nК моему сожалению ваше бронирование отмененили по решению администратора😢 \n\nВы можете связаться с ним для выяснения обстоятельств: @dabyt ")
            try await bot.sendMessage(params: userParams)
            
            bookingA.removeValue(forKey: userId)
        })
    }

    private static func sendAdmin(booking: Booking, bot: TGBotPrtcl, app: Vapor.Application) async throws {
        let message = """
        Новое бронирование✅:
        \nUser id: \(booking.userId)
        Имя хозяина: \(booking.userName)
        Имя собаки: \(booking.dogName)
        Порода собаки: \(booking.dogClass)
        Время: \(booking.time)
        Адрес: \(booking.loca)
        Контакты: \(booking.phnum)
        """
        app.logger.info("Инфа отправленна админу \(booking)")
        let buttons: [[TGInlineKeyboardButton]] = [
            [.init(text: "❌Отказаться❌", callbackData: "сancelbook")]
        ]
        let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
        let params: TGSendMessageParams = .init(chatId: .chat(adminUserId), text: message, replyMarkup: .inlineKeyboardMarkup(keyboard))
        try await bot.sendMessage(params: params)

        let payload = booki(userId: booking.userId, userName: booking.userName, dogName: booking.dogName, dogClass: booking.dogClass, time: booking.time, phnum: booking.phnum, loca: booking.loca)

        try await zapis(payload: payload, app: app)
    }

    private static func zapis(payload: booki, app: Vapor.Application) async throws {
        let client = app.client
        let url = URI(string: "http://62.84.115.125:5000/book")
        
        do {
            let response = try await client.post(url, headers: ["Content-Type": "application/json"]) { req in
                try req.content.encode(payload)
            }
            app.logger.info("Бронирование отправленно на сервер \(response.status)")
        } catch {
            app.logger.error("Ошибка отправки на сервер \(error)")
        }
    }

    private static func servhistory(userId: Int64, app: Vapor.Application) async throws -> [Booking] {
        let client = app.client
        let url = URI(string: "http://62.84.115.125:5000/history/\(userId)")
        
        do {
            let response = try await client.get(url)
            let bookings = try response.content.decode([BookingHistory].self).map {
                Booking(
                    userId: userId,
                    userName: $0.userName,
                    dogName: $0.dogName,
                    dogClass: $0.dogClass,
                    time: $0.time,
                    phnum: $0.phnum,
                    loca: $0.loca
                )
            }
            return bookings
        } catch {
            app.logger.error("Ошибка отправки истории \(userId): \(error)")
            throw error
        }
    }

    private static func SendHis(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/history"]) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            app.logger.info("\(userId) запросил историю")

            do {
                let bookings = try await servhistory(userId: userId, app: app)
                
                if bookings.isEmpty {
                    let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "У вас пока нет истории бронирований, но вы всегда можете ее пополнить!)")
                    try await bot.sendMessage(params: params)
                } else {
                    var message = "Ваша история бронирований:\n\n"
                    for booking in bookings {
                        message += """
                        Имя хозяина: \(booking.userName)
                        Имя собаки: \(booking.dogName)
                        Порода собаки: \(booking.dogClass)
                        Время: \(booking.time)
                        Адрес: \(booking.loca)
                        Контакты: \(booking.phnum)
                        \n\n
                        """
                    }
                    let params: TGSendMessageParams = .init(chatId: .chat(userId), text: message)
                    try await bot.sendMessage(params: params)
                }
            } catch {
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Произошла ошибка непредвиденная ошибка! \nМы стараемся как можно быстрее решить проблему! Приношу прощения за предоставленные неудобства! ;(")
                try await bot.sendMessage(params: params)
                app.logger.error("Ошибка отправки истории\(userId): \(error)")
            }
        })
    }

    private struct booki: Content {
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
    
    private struct BookingHistory: Content {
        let userName: String
        let dogName: String
        let dogClass: String
        let time: String
        let phnum: String
        let loca: String
        
        enum CodingKeys: String, CodingKey {
            case userName = "user_name"
            case dogName = "dog_name"
            case dogClass = "dog_class"
            case time
            case phnum
            case loca
        }
    }

}

enum BookingState {
    case nameus
    case dogname(userName: String)
    case dogclass(userName: String, dogName: String)
    case time(userName: String, dogName: String, dogClass: String)
    case loca(userName: String, dogName: String, dogClass: String, time: String)
    case phnum(userName: String, dogName: String, dogClass: String, time: String, loca: String)
}

struct Booking: Content {
    let userId: Int64
    let userName: String
    let dogName: String
    let dogClass: String
    let time: String
    let phnum: String
    let loca: String
}
