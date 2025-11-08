//
//  StatusIcon.swift
//  LuxaforPresence
//
//  Created by Gemini on 2025-11-05.
//

import Foundation
import AppKit

enum StatusIconName: String {
    case on = "StatusIconOn"
    case off = "StatusIconOff"
    case idle = "StatusIconIdle"
}

func statusImage(_ name: StatusIconName) -> NSImage? {
    let img = NSImage(named: name.rawValue)
    img?.isTemplate = true // usually redundant if Asset says “Template”, but harmless
    return img
}

