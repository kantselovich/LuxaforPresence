import AppKit
import ApplicationServices
import Foundation

struct AXNodeSnapshot: Equatable {
    let role: String?
    let roleDescription: String?
    let label: String?
    let placeholder: String?
    let domIdentifier: String?
}

protocol AXSnapshotProviding {
    func snapshot(bundleIdentifiers: [String], processNames: [String]) -> [AXNodeSnapshot]?
}

final class AccessibilitySnapshotProvider: AXSnapshotProviding {
    private let maxDepth: Int
    private let maxNodes: Int

    init(maxDepth: Int = 12, maxNodes: Int = 1500) {
        self.maxDepth = maxDepth
        self.maxNodes = maxNodes
    }

    func snapshot(bundleIdentifiers: [String], processNames: [String]) -> [AXNodeSnapshot]? {
        guard AXIsProcessTrusted() else { return nil }
        guard let app = runningApplication(bundleIdentifiers: bundleIdentifiers, processNames: processNames) else {
            return []
        }

        let root = AXUIElementCreateApplication(app.processIdentifier)
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var nodes: [AXNodeSnapshot] = []

        while let (element, depth) = queue.first {
            queue.removeFirst()
            if nodes.count >= maxNodes {
                break
            }

            let role = stringAttribute(element, kAXRoleAttribute)
            let roleDescription = stringAttribute(element, kAXRoleDescriptionAttribute)
            var label = stringAttribute(element, kAXLabelValueAttribute)
            if (label == nil || label?.isEmpty == true), role != (kAXWindowRole as String) {
                let title = stringAttribute(element, kAXTitleAttribute)
                if let title, !title.isEmpty {
                    label = title
                }
            }
            let placeholder = stringAttribute(element, kAXPlaceholderValueAttribute)
            let domIdentifier = stringAttribute(element, kAXDOMIdentifierAttribute)

            nodes.append(
                AXNodeSnapshot(
                    role: role,
                    roleDescription: roleDescription,
                    label: label,
                    placeholder: placeholder,
                    domIdentifier: domIdentifier
                )
            )

            if depth < maxDepth, let children = children(of: element) {
                children.forEach { queue.append(($0, depth + 1)) }
            }
        }

        return nodes
    }

    private func runningApplication(bundleIdentifiers: [String], processNames: [String]) -> NSRunningApplication? {
        let normalizedBundles = Set(bundleIdentifiers.map { $0.lowercased() })
        let normalizedNames = Set(processNames.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.first { app in
            if let bundle = app.bundleIdentifier?.lowercased(), normalizedBundles.contains(bundle) {
                return true
            }
            if let name = app.localizedName?.lowercased(), normalizedNames.contains(name) {
                return true
            }
            if let exe = app.executableURL?.lastPathComponent.lowercased(), normalizedNames.contains(exe) {
                return true
            }
            return false
        }
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? String
    }

    private func children(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard error == .success else { return nil }
        if let children = value as? [AXUIElement] {
            return children
        }
        if let array = value as? [Any] {
            return array.map { $0 as! AXUIElement }
        }
        return nil
    }
}
