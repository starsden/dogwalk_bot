import Foundation
import Vapor
import TelegramVaporBot

public func configure(_ app: Application) async throws {
    let tgApi: String = "7027076409:AAH9CxXVsHwTJQz7abqnKILV62-i3DNG7XI"
    TGBot.log.logLevel = app.logger.logLevel
    let bot: TGBot = .init(app: app, botId: tgApi)
    await TGBOT.setConnection(try await TGLongPollingConnection(bot: bot))
    
    await DefaultBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await TGBOT.connection.start()

    try routes(app)
}
