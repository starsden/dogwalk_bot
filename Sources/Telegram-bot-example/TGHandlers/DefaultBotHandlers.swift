import Vapor
import TelegramVaporBot

final class DefaultBotHandlers {
    private static var userStates: [Int64: BookingState] = [:]
    private static let adminUserId: Int64 = 6627628549

    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await commandPukHandler(app: app, connection: connection)
        await buttonsActionHandler(app: app, connection: connection)
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

    private static func buttonsActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
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
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как зовут вашу собаку?")
                try await bot.sendMessage(params: params)

            case .dogname(let userName):
                userStates[userId] = .dogclass(userName: userName, dogName: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Какой породы собака?")
                try await bot.sendMessage(params: params)

            case .dogclass(let userName, let dogName):
                userStates[userId] = .time(userName: userName, dogName: dogName, dogClass: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Когда нужно забрать \(dogName)?")
                try await bot.sendMessage(params: params)

                
                
            case .time(let userName, let dogName, let dogClass):
                userStates[userId] = .loca(userName: userName, dogName: dogName, dogClass: dogClass, time: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Откуда забрать \(dogName)?")
                try await bot.sendMessage(params: params)

                
                
            case .loca(let userName, let dogName, let dogClass, let time):
                userStates[userId] = .phnum(userName: userName, dogName: dogName, dogClass: dogClass, time: time, loca: update.message?.text ?? "")
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Как с вами связаться?")
                try await bot.sendMessage(params: params)

            case .phnum(let userName, let dogName, let dogClass, let time, let loca):
                let phnum = update.message?.text ?? ""
                let booking = Booking(userName: userName, dogName: dogName, dogClass: dogClass, time: time, phnum: phnum, loca: loca)
                try await sendBookingToAdmin(booking: booking, bot: bot)
                userStates.removeValue(forKey: userId)
                let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Бронирование успешно завершено. Спасибо!")
                try await bot.sendMessage(params: params)
            }
        })
    }

    
    private static func buttonsActionHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCallbackQueryHandler(pattern: "moreinf") { update, bot in
            guard let userId = update.callbackQuery?.from.id else { return }
            let params: TGSendMessageParams = .init(chatId: .chat(userId), text: "Гуляю собак от больших до маленьких. Люблю всех. \n400 рублей - 40 минут")
            try await bot.sendMessage(params: params)
        })
    
    
    
    private static func sendBookingToAdmin(booking: Booking, bot: TGBotPrtcl) async throws {
        let message = """
        Новое бронирование✅:
        Имя хозяина: \(booking.userName)
        Имя собаки: \(booking.dogName)
        Порода собаки: \(booking.dogClass)
        Время забора: \(booking.time)
        Контактная информация: \(booking.phnum)
        Откуда забрать: \(booking.loca)
        """
        let params: TGSendMessageParams = .init(chatId: .chat(adminUserId), text: message)
        try await bot.sendMessage(params: params)
    }

    private static func commandPukHandler(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/puk"]) { update, bot in
            try await update.message?.reply(text: "членус", bot: bot)
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
