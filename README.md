# LuxaforPresence for macOS

A small, sandboxed macOS menu bar app that infers if you are in a meeting and updates your Luxafor flag.

## Prerequisites

*   macOS 13.0+
*   Xcode 14.0+ (for command line tools)
*   A Luxafor device and your Luxafor API `userId`.

## Setup

1.  **Clone the repository.**
2.  **Provide Luxafor User ID:**
    *   The `userId` is loaded from a configuration file. You have two options:
    *   **Option 1: (Recommended)** Create a configuration file at `~/.config/LuxaforPresence/config.plist`. The app will create the directory for you. You can copy the bundled config file and edit it.
    *   **Option 2:** Edit the bundled configuration file at `LuxaforPresence/Resources/config.plist` and replace `YOUR_USER_ID_HERE` with your actual Luxafor `userId`. Note that this change will be overwritten if you pull new updates from the repository.
    ```xml
    <!-- ~/.config/LuxaforPresence/config.plist -->
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>userId</key>
        <string>YOUR_USER_ID_HERE</string>
    </dict>
    </plist>
    ```
3.  **Add Status Bar Icons:**
    *   Create an asset catalog at `LuxaforPresence/Resources/Assets.xcassets`.
    *   Inside the asset catalog, add three new image sets for the status bar icon:
        *   `StatusIconOn` (for the "in meeting" state)
        *   `StatusIconOff` (for the "not in meeting" state)
        *   `StatusIconIdle` (for the "unknown" state)
    *   Ensure they are marked as "Template Image" in the asset catalog's attribute inspector.

## How to Build and Run

1.  **Build the project:**
    ```bash
    swift build
    ```
2.  **Run the application:**
    The executable will be located in `.build/debug/LuxaforPresence`. You can run it directly, but to launch it as a proper macOS app, it's better to use the `swift run` command:
    ```bash
    swift run
    ```
    The app will launch, and its icon will appear in the menu bar.

    To run in release mode for better performance:
    ```bash
    swift run -c release
    ```

## How to Run Tests

```bash
swift test
```

## How to Install Dependencies

This project uses native macOS frameworks (`AppKit`, `AVFoundation`, `CoreAudio`, `EventKit`) and has no external package dependencies. The Swift Package Manager will handle the project setup.