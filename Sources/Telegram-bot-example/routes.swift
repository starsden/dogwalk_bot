import Vapor
import TelegramVaporBot


func routes(_ app: Application) throws {
    try app.register(collection: TelegramController())
}

