# Gongfu Timer

An iOS timer for gongfu-style tea brewing, written in SwiftUI.

## Features

**Free**
- Steep timer with a progress ring, rinse step and per-infusion schedule (first steep + increment)
- Adjust any infusion by ±5s, skip ahead or keep steeping past the planned count
- Chime, haptics and a notification when a steep finishes; screen stays awake while steeping
- Tea library with 8 presets (green, white, oolong, roasted oolong, black, sheng and shou pu-erh), editable and extendable
- Layout adapts from iPhone SE up to the largest iPhones and iPad

**Pro** (one-time in-app purchase, €4.99)
- **History** – every session logged with tea, time, infusions and total steep time
- **Stats** – activity, time of day, favourite teas, tea types, streaks
- **Inventory** – grams on hand per tea; one session's worth (grams per session) is deducted automatically

## Requirements

- Xcode 27 or newer
- iOS 17 or newer

## Running

Open `GongfuTimer.xcodeproj` and press Run. The shared scheme uses `Configuration.storekit`, so the Pro purchase can be tested locally without App Store Connect (Debug → StoreKit → Manage Transactions to reset it).

Debug-only launch arguments (in the scheme, disabled by default):

- `-unlockPro` – treat Pro as purchased
- `-seedHistory` – fill an empty history with ~60 days of sample sessions

## Project layout

| File | Purpose |
|---|---|
| `GongfuTimerApp.swift` | App entry and tab bar |
| `ContentView.swift` | Brew screen (timer) |
| `SteepTimer.swift` | Countdown, notifications, haptics |
| `Models.swift` / `TeaStore.swift` | Tea model, presets, persistence |
| `TeaLibraryView.swift` | Tea picker and editor |
| `HistoryStore.swift` / `HistoryView.swift` | Session log |
| `StatsView.swift` | Charts and summary |
| `InventoryView.swift` | Stock tracking |
| `ProStore.swift` / `PaywallView.swift` | StoreKit 2 purchase and paywall |

## Before shipping

- Replace the bundle ID `com.example.GongfuTimer` and the product ID in `ProStore.swift` with your own
- Create the matching non-consumable in-app purchase in App Store Connect
- Add an app icon
