import Foundation

public struct UsageResponse: Decodable, Equatable, Sendable {
    public var planType: String?
    public var rateLimit: RateLimit?
    public var credits: Credits?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
    }

    public init(planType: String?, rateLimit: RateLimit?, credits: Credits?) {
        self.planType = planType
        self.rateLimit = rateLimit
        self.credits = credits
    }
}

public struct RateLimit: Decodable, Equatable, Sendable {
    public var primaryWindow: QuotaWindow?
    public var secondaryWindow: QuotaWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

public struct QuotaWindow: Codable, Equatable, Sendable {
    public var usedPercent: Double?
    public var remainingPercent: Double?
    public var used: Double?
    public var limit: Double?
    public var resetAt: Date?
    public var resetsInSeconds: Double?
    public var limitWindowSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case remainingPercent = "remaining_percent"
        case used
        case limit
        case resetAt = "reset_at"
        case resetsInSeconds = "resets_in_seconds"
        case limitWindowSeconds = "limit_window_seconds"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try c.decodeFlexibleDoubleIfPresent(forKey: .usedPercent)
        remainingPercent = try c.decodeFlexibleDoubleIfPresent(forKey: .remainingPercent)
        used = try c.decodeFlexibleDoubleIfPresent(forKey: .used)
        limit = try c.decodeFlexibleDoubleIfPresent(forKey: .limit)
        resetsInSeconds = try c.decodeFlexibleDoubleIfPresent(forKey: .resetsInSeconds)
        resetAt = try c.decodeFlexibleDateIfPresent(forKey: .resetAt)
        limitWindowSeconds = try c.decodeFlexibleDoubleIfPresent(forKey: .limitWindowSeconds)
    }
}

public struct Credits: Codable, Equatable, Sendable {
    public var granted: Double?
    public var used: Double?
    public var remaining: Double?
    public var balance: Double?
    public var hasCredits: Bool?
    public var unlimited: Bool?

    enum CodingKeys: String, CodingKey {
        case granted
        case used
        case remaining
        case balance
        case hasCredits = "has_credits"
        case unlimited
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        granted = try c.decodeFlexibleDoubleIfPresent(forKey: .granted)
        used = try c.decodeFlexibleDoubleIfPresent(forKey: .used)
        remaining = try c.decodeFlexibleDoubleIfPresent(forKey: .remaining)
        balance = try c.decodeFlexibleDoubleIfPresent(forKey: .balance)
        hasCredits = try c.decodeIfPresent(Bool.self, forKey: .hasCredits)
        unlimited = try c.decodeIfPresent(Bool.self, forKey: .unlimited)
    }
}

public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public var snapshotID: UUID
    public var fetchedAt: Date
    public var planType: String?
    public var session: QuotaWindow?
    public var weekly: QuotaWindow?
    public var credits: Credits?
    public var error: String?

    public init(snapshotID: UUID, fetchedAt: Date = Date(), usage: UsageResponse, error: String? = nil) {
        self.snapshotID = snapshotID
        self.fetchedAt = fetchedAt
        planType = usage.planType
        session = usage.rateLimit?.primaryWindow
        weekly = usage.rateLimit?.secondaryWindow
        credits = usage.credits
        self.error = error
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func decodeFlexibleDateIfPresent(forKey key: Key) throws -> Date? {
        if let value = try? decodeIfPresent(Date.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return fractional.date(from: value) ?? plain.date(from: value)
        }
        if let seconds = try? decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let seconds = try? decodeIfPresent(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(seconds))
        }
        return nil
    }
}
