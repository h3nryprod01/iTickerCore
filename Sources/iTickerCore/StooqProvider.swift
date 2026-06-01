import Foundation

// MARK: - StooqProvider

// NOTE: Stooq uses an unofficial CSV endpoint. Symbol mapping: lowercase the ticker
// and append ".us" if there is no dot (e.g. AAPL -> aapl.us, BRK.B -> brk.b).
// The ".us" assumption covers the majority of US-listed symbols but will be wrong
// for non-US instruments — callers should only use this provider for US equities.
public struct StooqProvider: PriceProvider {
    public let assetClass: AssetClass = .intlEquity

    private let session: URLSession
    private let baseURL: URL

    public init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://stooq.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: Quotes

    public func quotes(for instruments: [Instrument]) async throws(ProviderError) -> [Quote] {
        guard !instruments.isEmpty else { return [] }
        var results: [Quote] = []
        for instrument in instruments {
            if let quote = try await fetchQuote(instrument: instrument) {
                results.append(quote)
            }
        }
        return results
    }

    // MARK: Chart

    public func chart(
        for instrument: Instrument,
        interval: ChartInterval
    ) async throws(ProviderError) -> [ChartPoint] {
        let csv = try await fetchCSV(symbol: instrument.symbol)
        let rows = parseCSV(csv)
        guard !rows.isEmpty else { return [] }

        // Filter to the interval window
        let cutoff = Date.now.addingTimeInterval(-Self.intervalSeconds(interval))
        return rows.compactMap { row in
            guard row.date >= cutoff else { return nil }
            return ChartPoint(
                timestamp: row.date,
                close: row.close,
                open: row.open,
                high: row.high,
                low: row.low,
                volume: row.volume
            )
        }
    }

    // MARK: Internal decode seam (for tests)

    static func decodeQuote(csv: String, symbol: String) throws(ProviderError) -> Quote? {
        let rows = parseCSVString(csv)
        return buildQuote(from: rows, symbol: symbol)
    }

    static func decodeChart(csv: String, interval: ChartInterval) throws(ProviderError) -> [ChartPoint] {
        let rows = parseCSVString(csv)
        guard !rows.isEmpty else { return [] }
        let cutoff = Date.now.addingTimeInterval(-Self.intervalSeconds(interval))
        return rows.compactMap { row in
            guard row.date >= cutoff else { return nil }
            return ChartPoint(
                timestamp: row.date,
                close: row.close,
                open: row.open,
                high: row.high,
                low: row.low,
                volume: row.volume
            )
        }
    }

    // MARK: Private helpers

    private func fetchQuote(instrument: Instrument) async throws(ProviderError) -> Quote? {
        let symbol = instrument.symbol
        let csv = try await fetchCSV(symbol: symbol)
        let rows = parseCSV(csv)
        return Self.buildQuote(from: rows, instrument: instrument)
    }

    private func fetchCSV(symbol: String) async throws(ProviderError) -> String {
        let stooqSymbol = Self.mapSymbol(symbol)
        var components = URLComponents(
            url: baseURL.appendingPathComponent("q/d/l/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "s", value: stooqSymbol),
            URLQueryItem(name: "i", value: "d"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("iTicker/1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw .rateLimited }
            if http.statusCode == 404 { throw .notFound(symbol) }
            if http.statusCode != 200 { throw .invalidResponse(http.statusCode) }
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw .decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Non-UTF8 CSV")))
        }
        // Stooq returns "No data" body when symbol not found
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased().hasPrefix("no data") {
            throw .notFound(symbol)
        }
        return trimmed
    }

    private func parseCSV(_ text: String) -> [CSVRow] {
        Self.parseCSVString(text)
    }

    private static func parseCSVString(_ text: String) -> [CSVRow] {
        let lines = text.components(separatedBy: "\n")
        // Skip header (first line) and parse remaining
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        var rows: [CSVRow] = []
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: ",")
            guard parts.count >= 5 else { continue }
            guard let date = dateFormatter.date(from: parts[0]) else { continue }
            guard let open = Double(parts[1]),
                  let high = Double(parts[2]),
                  let low = Double(parts[3]),
                  let close = Double(parts[4]) else { continue }
            let volume: Double? = parts.count >= 6 ? Double(parts[5]) : nil
            rows.append(CSVRow(date: date, open: open, high: high, low: low, close: close, volume: volume))
        }
        return rows
    }

    private static func buildQuote(from rows: [CSVRow], symbol: String) -> Quote? {
        let instrument = Instrument(
            id: symbol, symbol: symbol, name: symbol,
            assetClass: .intlEquity, providerID: symbol
        )
        return buildQuote(from: rows, instrument: instrument)
    }

    private static func buildQuote(from rows: [CSVRow], instrument: Instrument) -> Quote? {
        guard !rows.isEmpty else { return nil }
        let last = rows[rows.count - 1]
        let prev: CSVRow? = rows.count >= 2 ? rows[rows.count - 2] : nil

        let change24h: Double? = prev.map { last.close - $0.close }
        let changePct24h: Double? = prev.flatMap { p in
            guard p.close != 0 else { return nil }
            return (last.close - p.close) / p.close * 100
        }

        return Quote(
            instrument: instrument,
            price: last.close,
            change24h: change24h,
            changePct24h: changePct24h,
            volume24h: last.volume,
            currency: currency(forStooqSymbol: mapSymbol(instrument.symbol))
        )
    }

    static func mapSymbol(_ symbol: String) -> String {
        let lower = symbol.lowercased()
        return lower.contains(".") ? lower : "\(lower).us"
    }

    /// Infer the ISO 4217 currency from a Stooq symbol's exchange suffix
    /// (e.g. "air.pa" → EUR, "vod.uk" → GBP). Defaults to USD for US/unknown.
    static func currency(forStooqSymbol stooq: String) -> String {
        guard let dot = stooq.lastIndex(of: ".") else { return "USD" }
        let suffix = String(stooq[stooq.index(after: dot)...]).lowercased()
        switch suffix {
        case "us": return "USD"
        case "uk", "l": return "GBP"
        case "de", "f", "pa", "as", "mi", "mc", "br", "lu", "pt", "ie", "at", "fi", "gr", "es", "be", "nl": return "EUR"
        case "sw", "vx": return "CHF"
        case "jp", "t": return "JPY"
        case "hk": return "HKD"
        case "au": return "AUD"
        case "ca", "to", "v": return "CAD"
        case "vn": return "VND"
        default: return "USD"
        }
    }

    private static func intervalSeconds(_ interval: ChartInterval) -> TimeInterval {
        switch interval {
        case .day: return 86400
        case .week: return 7 * 86400
        case .month: return 30 * 86400
        case .threeMonths: return 90 * 86400
        case .year: return 365 * 86400
        }
    }
}

// MARK: - CSV Row

private struct CSVRow {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
}
