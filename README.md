# Print & Inventory Management App

A robust Flutter application designed for managing inventory shifts, performing unit conversions, and printing direct receipts to network-based ESC/POS thermal printers. 

This app is tailored to solve the problem of tracking daily ingredient consumption in food/restaurant businesses, with automatic calculation of portions and free-text printing capabilities.

## 🌟 Key Features

* **Advanced ESC/POS Printing**: Print directly to local network thermal printers (port 9100).
* **Unicode & Vietnamese Support**: All receipts are rendered into raster images before printing, ensuring 100% accurate display of Vietnamese diacritics and special characters without encoding issues.
* **Smart Inventory Tracking**: 
  * Define items with base units (e.g., grams) and custom conversion rates (e.g., 33g = 1 Portion).
  * Support for multiple custom units per item.
* **Shift Management**: Create shifts, log ingredient usage, and automatically group/calculate consumed portions vs. remainders.
* **Telegram Cloud Sync**: Instantly push shift summary reports to a Telegram chat using a Bot for secure, real-time backup and reporting.
* **Responsive Settings**: Configure Printer IP, Port, Paper Size (58mm or 80mm), and Dark/Light mode preferences.

## 📂 Project Structure

The project follows a clean, feature-based and layered architecture to ensure scalability and maintainability.

```text
lib/
├── core/                           # Core infrastructure & shared utilities
│   ├── database/                   # SQLite database configuration and queries
│   ├── printing/                   # ESC/POS Network printing & PaperSize enums
│   ├── storage/                    # Local SharedPreferences management
│   └── utils/                      # Helper classes (e.g., text formatters)
│
├── features/                       # Independent feature modules
│   ├── free_print/                 # Free-text printing module
│   │   └── screens/
│   ├── inventory/                  # Core inventory & shift management module
│   │   ├── models/                 # Data models (Item, ShiftRecord, EntryLog)
│   │   ├── screens/                # UI screens for inventory
│   │   └── services/               # Telegram Sync Service
│   ├── navigation/                 # Main bottom navigation bar logic
│   └── settings/                   # App & Printer configuration UI
│
└── main.dart                       # App entry point
```

## 🚀 Getting Started

### 1. Environment Setup

To use the Telegram Sync feature, you must create a `.env` file at the root of the project to securely store your API credentials. **Never commit this file to version control.**

Create a `.env` file and add the following keys:

```env
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
TELEGRAM_CHAT_ID=your_telegram_chat_id_here
```

### 2. Install Dependencies

Run the following command to fetch all required Flutter packages:

```bash
flutter pub get
```

### 3. Run the App

You can run the app on an Android/iOS emulator or a physical device:

```bash
flutter run
```

## 📖 User Guide

### 1. Configure the Printer
- Navigate to the **Settings** tab.
- Enter the IP Address of your ESC/POS thermal printer (must be on the same local network).
- Choose the paper size (`58` or `80`).

### 2. Configure Inventory Items
- Also in the **Settings** tab, tap on "Cài đặt món ăn & Định mức" (Item & Conversion Settings).
- Add items, set their default base unit (e.g., `g`, `con`), and specify how many base units make up 1 Portion (`P`).

### 3. Manage Shifts
- Go to the **Inventory** tab to see your shift history.
- Create a new shift to start tracking.
- Tap on items to log consumption. You can enter values in base units or custom units.
- Tap the **Print** icon on the top right of a shift to view a summary and print the receipt.
- Tap the **Cloud Upload** icon to sync the shift data to Telegram.

---

*Developed with Flutter & SQLite.*
