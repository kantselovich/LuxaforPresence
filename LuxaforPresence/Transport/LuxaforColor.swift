import Foundation

enum LuxaforColor {
    case red
    case orange
    case off

    var hex: String {
        switch self {
        case .red:
            return "FF0000"
        case .orange:
            return "FF7000"
        case .off:
            return "000000"
        }
    }

    var localHex: String {
        "#\(hex)"
    }

    var remoteActionFields: [String: Any] {
        ["color": "custom", "custom_color": hex]
    }
}
