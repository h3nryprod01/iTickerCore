# iTickerCore

The open **core** of **iTicker** — a finance portfolio tracker for
macOS, iPadOS, and iOS. This Swift package contains all the non‑UI logic: market‑data
providers, exchange connectivity, P/L math, search, and currency handling. The app's UI
is closed‑source; **this core is open so anyone can audit exactly how it talks to the
network and how it handles your exchange keys.**

> **Why open this?** iTicker has **no backend**. It asks for a *read‑only* Binance API key
> to show your balances. This package is the proof of that promise: the signing code never
> sends your secret anywhere — it only uses it locally to sign read‑only requests. Read it
> yourself.

## Trust at a glance

- **No server.** Every provider calls a public market API directly from the device.
- **Read‑only exchange access.** `BinanceAccountService` signs `GET /api/v3/account` with
  HMAC‑SHA256 **locally**. Your API **secret is never transmitted** — only the signature is.
  The HMAC implementation is verified against Binance's official documented test vector
  (`BinanceAccountServiceTests`).
- **No secrets in this repo.** No API keys, tokens, or credentials. (User keys live only in
  the device Keychain, which is in the closed app target — not here.)
- **No analytics, no tracking.** This package imports only Foundation + CryptoKit.

## What's inside

| Area | Files |
|------|-------|
| Provider protocol + routing | `PriceProvider`, `QuoteService`, `FallbackProvider` |
| Crypto | `CryptoProvider` (CoinGecko), `BinanceProvider`, `CoinCapProvider` |
| VN equities | `VNStockProvider` (TCBS), `VNDirectProvider`, `SSIProvider` |
| International equities | `IntlStockProvider` (Yahoo), `StooqProvider` |
| Exchange sync | `BinanceAccountService` (read‑only, HMAC‑SHA256) |
| Search | `SymbolSearchProvider`, `SearchMerge`, `PresetCatalog` |
| Math & FX | `PLMath`, `PortfolioSummary`, `FXRateService` |
| Models | `Models` (Instrument, Quote, AssetClass, …) |

All third‑party stock endpoints (TCBS/VNDirect/SSI for Vietnam, Yahoo/Stooq for
international) are **unofficial public endpoints** and may change or rate‑limit; each lives
in one isolated file behind the `PriceProvider` protocol so a source can be swapped easily.

## Build & test

```bash
swift build
swift test     # fixture-based, no live network, no real secrets
```

Requires Swift 5.9+, macOS 14+/iOS 17+.

## Status

Extracted from the iTicker app. Issues and PRs welcome, especially around data‑source
resilience. The closed app links this package; the package itself is MIT‑licensed.

## License

[MIT](LICENSE) © 2026 Nguyễn Phúc Ường
