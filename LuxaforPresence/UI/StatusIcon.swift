//
//  StatusIcon.swift
//  LuxaforPresence
//
//  Created by Gemini on 2025-11-05.
//

import AppKit

enum StatusIconName {
    case on, off, idle

    private struct Asset {
        let fileName: String
        let directory: String
    }

    private var asset: Asset {
        switch self {
        case .on:
            return Asset(fileName: "circle.circle.fill", directory: "Assets.xcassets/StatusIconOn.imageset")
        case .off:
            return Asset(fileName: "circle", directory: "Assets.xcassets/StatusIconOff.imageset")
        case .idle:
            return Asset(fileName: "questionmark.circle", directory: "Assets.xcassets/StatusIconIdle.imageset")
        }
    }

    func image() -> NSImage? {
        guard
            let url = Bundle.module.url(
                forResource: asset.fileName,
                withExtension: "png",
                subdirectory: asset.directory
            ),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
