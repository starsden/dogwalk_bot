import Vapor
import TelegramVaporBot

final class DefaultBotHandlers {
    private static var userStates: [Int64: BookingState] = [:]
    private static let adminUserId: Int64 = 6627628549

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
                                                    text: "Доброго времени суток! \nЯ помогу вам забронировать время для прогулки с вашей собакой.",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
        })
    }
            ///Имя хозяина начало
    private static func bookHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "time") { update, bot in
            guard let userId = update.callbackQuery?.from.id else { return }
            userStates[userId] = .nameus
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как вас зовут?")
            try await bot.sendMessage(params: params)
        })
        await connection.dispatcher.add(TGMessageHandler(filters: .all) { update, bot in
            guard let userId = update.message?.from?.id else { return }
            guard let state = userStates[userId] else { return }
            
            switch state {
            case .nameus:
                userStates[userId] = .dogname(userName: update.message?.text ?? "")
            ///имя хозяина конец
                
            ///имя собаки начало
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как зовут вашу собаку?")
                try await bot.sendMessage(params: params)
            case .dogname(let userName):
                userStates[userId] = .dogclass(userName: userName, dogName: update.message?.text ?? "")
           ///имя собаки конец
                
            ///порода начало
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Какой породы собака?")
                try await bot.sendMessage(params: params)
            case .dogclass(let userName, let dogName):
                userStates[userId] = .time(userName: userName, dogName: dogName, dogClass: update.message?.text ?? "")
            ///порода конец
                
            ///когда забрать нчало
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Когда нужно забрать \(dogName)?")
                try await bot.sendMessage(params: params)
            case .time(let userName, let dogName, let dogClass):
                userStates[userId] = .loca(userName: userName, dogName: dogName, dogClass: dogClass, time: update.message?.text ?? "")
            ///когда забрать конец
                
            
            ///откуда забрать начало
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Откуда забрать \(dogName)?")
                try await bot.sendMessage(params: params)
            case .loca(let userName, let dogName, let dogClass, let time):
                userStates[userId] = .phnum(userName: userName, dogName: dogName, dogClass: dogClass, time: time, loca: update.message?.text ?? "")
            ///Откуда забрать конец
                
            
                
                
            ///номер телефона начало
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
                    phnum = update.message?.text ?? ""
                }
            ///номер телефона конец
                
                
                let booking = Booking(userName: userName, dogName: dogName, dogClass: dogClass, time: time, phnum: phnum, loca: loca)
                try await sendBookingToAdmin(booking: booking, bot: bot)
                userStates.removeValue(forKey: userId)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Бронирование успешно завершено. Спасибо!")
                try await bot.sendMessage(params: params)
            }
        })
//УЗНАТЬ ПОДРОБНЕЕ НАЧАЛО
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "moreinf") { update, bot in
            guard let userId = update.callbackQuery?.from.id, let messageId = update.callbackQuery?.message?.messageId else { return }
            try await bot.deleteMessage(params: .init(chatId: .chat(userId), messageId: messageId))
            let buttons: [[TGInlineKeyboardButton]] = [
                [.init(text: "Вернуться", callbackData: "goback")]
            ]
            let keyboard: TGInlineKeyboardMarkup = .init(inlineKeyboard: buttons)
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Гуляю всех собак, от больших до маленьких. Люблю всех. \n\n400 рублей  - 40 минут", replyMarkup: .inlineKeyboardMarkup(keyboard))
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
                                                    text: "Доброго времени суток! \nЯ помогу вам забронировать время для прогулки с вашей собакой.",
                                                    replyMarkup: .inlineKeyboardMarkup(keyboard))
            try await bot.sendMessage(params: params)
//УЗНАТЬ ПОДРОБНЕЕ КОНЕЦ
        })
    }
///шаблон отправки админу
    private static func sendBookingToAdmin(booking: Booking, bot: TGBotPrtcl) async throws {
        let message = """
        Новое бронирование✅:
        \nИмя хозяина: \(booking.userName)
        Имя собаки: \(booking.dogName)
        Порода собаки: \(booking.dogClass)
        Время: \(booking.time)
        Адрес: \(booking.loca)
        Контакты: \(booking.phnum)
        """
        let params: TGSendMessageParams = .init(chatId: .chat(adminUserId), text: message)
        try await bot.sendMessage(params: params)
        print(message)
    }

    private static func commandstatkHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/http"]) { update, bot in
            try await update.message?.reply(text: "status 200", bot: bot)
        })
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

struct Booking {
    let userName: String
    let dogName: String
    let dogClass: String
    let time: String
    let phnum: String
    let loca: String
}
