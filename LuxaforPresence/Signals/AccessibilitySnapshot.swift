import AppKit
import ApplicationServices
import Foundation
import OSLog

struct AXNodeSnapshot: Equatable {
    let role: String?
    let roleDescription: String?
    let label: String?
    let placeholder: String?
    let domIdentifier: String?
    let identifier: String?
    let pid: Int32?
}

protocol AXSnapshotProviding {
    func snapshot(bundleIdentifiers: [String], processNames: [String]) -> [AXNodeSnapshot]?
}

final class AccessibilitySnapshotProvider: AXSnapshotProviding {
    private let logger = Logger(subsystem: "com.example.LuxaforPresence", category: "AccessibilitySnapshot")
    private let maxDepth: Int
    private let maxNodes: Int

    init(maxDepth: Int = 36, maxNodes: Int = 3600) {
        self.maxDepth = maxDepth
        self.maxNodes = maxNodes
    }

    func snapshot(bundleIdentifiers: [String], processNames: [String]) -> [AXNodeSnapshot]? {
        guard AXIsProcessTrusted() else {
            AccessibilityTrustDiagnostics.logNotTrusted(logger: logger, context: "snapshot")
            logger.info("AX snapshot unavailable: not trusted")
            return nil
        }
        let apps = runningApplications(bundleIdentifiers: bundleIdentifiers, processNames: processNames)
        guard !apps.isEmpty else {
            logger.debug("AX snapshot: no running app for bundles=\(bundleIdentifiers, privacy: .public) names=\(processNames, privacy: .public)")
            return []
        }
        if apps.count > 1 {
            logger.debug(
                "AX snapshot: found \(apps.count, privacy: .public) matching apps \(self.formatApps(apps), privacy: .public)"
            )
        }

        var allNodes: [AXNodeSnapshot] = []
        for app in apps {
            allNodes.append(contentsOf: snapshotNodes(for: app))
        }
        return allNodes
    }

    private func snapshotNodes(for app: NSRunningApplication) -> [AXNodeSnapshot] {
        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        let hasFocusedWindow = self.hasFocusedWindow(app)
        let pid = app.processIdentifier
        logger.debug(
            "AX snapshot: app bundle=\(app.bundleIdentifier ?? "unknown", privacy: .public) name=\(app.localizedName ?? "unknown", privacy: .public) pid=\(pid, privacy: .public) frontmost=\(isFrontmost) focusedWindow=\(hasFocusedWindow)"
        )

        let root = AXUIElementCreateApplication(app.processIdentifier)
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var nodes: [AXNodeSnapshot] = []
        var maxDepthVisited = 0
        var maxNodesHit = false
        var maxDepthHit = false
        var dequeuedCount = 0
        var appendedCount = 0
        var roleCount = 0
        var roleDescriptionCount = 0
        var labelCount = 0
        var placeholderCount = 0
        var domIdentifierCount = 0
        var identifierCount = 0
        var attributeErrorCounts: [String: Int] = [:]
        var attributeEmptyCounts: [String: Int] = [:]
        var attributeNonStringCounts: [String: Int] = [:]
        var childrenFetchErrorCount = 0
        var childrenNonArrayCount = 0
        var childBucketZero = 0
        var childBucketSmall = 0
        var childBucketMedium = 0
        var childBucketLarge = 0

        while let (element, depth) = queue.first {
            queue.removeFirst()
            dequeuedCount += 1
            if nodes.count >= maxNodes {
                maxNodesHit = true
                break
            }
            if depth > maxDepthVisited {
                maxDepthVisited = depth
            }

            let role = stringAttribute(
                element,
                kAXRoleAttribute,
                errorCounts: &attributeErrorCounts,
                emptyCounts: &attributeEmptyCounts,
                nonStringCounts: &attributeNonStringCounts
            )
            let roleDescription = stringAttribute(
                element,
                kAXRoleDescriptionAttribute,
                errorCounts: &attributeErrorCounts,
                emptyCounts: &attributeEmptyCounts,
                nonStringCounts: &attributeNonStringCounts
            )
            var label = stringAttribute(
                element,
                kAXLabelValueAttribute,
                errorCounts: &attributeErrorCounts,
                emptyCounts: &attributeEmptyCounts,
                nonStringCounts: &attributeNonStringCounts
            )
            if (label == nil || label?.isEmpty == true), role != (kAXWindowRole as String) {
                let title = stringAttribute(
                    element,
                    kAXTitleAttribute,
                    errorCounts: &attributeErrorCounts,
                    emptyCounts: &attributeEmptyCounts,
                    nonStringCounts: &attributeNonStringCounts
                )
                if let title, !title.isEmpty {
                    label = title
                }
            }
            let placeholder = stringAttribute(
                element,
                kAXPlaceholderValueAttribute,
                errorCounts: &attributeErrorCounts,
                emptyCounts: &attributeEmptyCounts,
                nonStringCounts: &attributeNonStringCounts
            )
            let domIdentifier = stringAttribute(
                element,
                kAXDOMIdentifierAttribute,
                errorCounts: &attributeErrorCounts,
                emptyCounts: &attributeEmptyCounts,
                nonStringCounts: &attributeNonStringCounts
            )
            let identifier = stringAttribute(
                element,
                kAXIdentifierAttribute,
                errorCounts: &attributeErrorCounts,
                emptyCounts: &attributeEmptyCounts,
                nonStringCounts: &attributeNonStringCounts
            )
            if role != nil { roleCount += 1 }
            if roleDescription != nil { roleDescriptionCount += 1 }
            if label != nil { labelCount += 1 }
            if placeholder != nil { placeholderCount += 1 }
            if domIdentifier != nil { domIdentifierCount += 1 }
            if identifier != nil { identifierCount += 1 }

            nodes.append(
                AXNodeSnapshot(
                    role: role,
                    roleDescription: roleDescription,
                    label: label,
                    placeholder: placeholder,
                    domIdentifier: domIdentifier,
                    identifier: identifier,
                    pid: pid
                )
            )

            let children = children(
                of: element,
                fetchErrorCount: &childrenFetchErrorCount,
                nonArrayCount: &childrenNonArrayCount
            )
            let childCount = children?.count ?? 0
            if childCount == 0 {
                childBucketZero += 1
            } else if childCount <= 3 {
                childBucketSmall += 1
            } else if childCount <= 10 {
                childBucketMedium += 1
            } else {
                childBucketLarge += 1
            }

            if depth < maxDepth {
                if let children, !children.isEmpty {
                    appendedCount += children.count
                    children.forEach { queue.append(($0, depth + 1)) }
                }
            } else if let children, !children.isEmpty {
                maxDepthHit = true
            }
        }

        logger.debug(
            "AX snapshot summary: pid=\(pid, privacy: .public) nodes=\(nodes.count) dequeued=\(dequeuedCount) appended=\(appendedCount) maxDepthVisited=\(maxDepthVisited) maxDepth=\(self.maxDepth) maxDepthHit=\(maxDepthHit) maxNodes=\(self.maxNodes) maxNodesHit=\(maxNodesHit) role=\(roleCount) roleDesc=\(roleDescriptionCount) label=\(labelCount) placeholder=\(placeholderCount) domId=\(domIdentifierCount) identifier=\(identifierCount)"
        )
        logger.debug(
            "AX snapshot attributes: pid=\(pid, privacy: .public) errors=\(self.formatCounts(attributeErrorCounts), privacy: .public) empty=\(self.formatCounts(attributeEmptyCounts), privacy: .public) nonString=\(self.formatCounts(attributeNonStringCounts), privacy: .public)"
        )
        logger.debug(
            "AX snapshot children: pid=\(pid, privacy: .public) zero=\(childBucketZero) small=\(childBucketSmall) medium=\(childBucketMedium) large=\(childBucketLarge) fetchErrors=\(childrenFetchErrorCount) nonArray=\(childrenNonArrayCount)"
        )
        return nodes
    }

    private func runningApplications(bundleIdentifiers: [String], processNames: [String]) -> [NSRunningApplication] {
        let normalizedBundles = Set(bundleIdentifiers.map { $0.lowercased() })
        let normalizedNames = Set(processNames.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.filter { app in
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

    private func formatApps(_ apps: [NSRunningApplication]) -> String {
        apps.map { app in
            let bundle = app.bundleIdentifier ?? "unknown"
            let name = app.localizedName ?? "unknown"
            let pid = app.processIdentifier
            return "\(name) [\(bundle)] pid=\(pid)"
        }
        .joined(separator: "; ")
    }

    private func hasFocusedWindow(_ app: NSRunningApplication) -> Bool {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(root, kAXFocusedWindowAttribute as CFString, &value)
        return error == .success && value != nil
    }

    private func stringAttribute(
        _ element: AXUIElement,
        _ attribute: String,
        errorCounts: inout [String: Int],
        emptyCounts: inout [String: Int],
        nonStringCounts: inout [String: Int]
    ) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            errorCounts[attribute, default: 0] += 1
            return nil
        }
        if let attributedValue = value as? NSAttributedString {
            let stringValue = attributedValue.string
            if stringValue.isEmpty {
                emptyCounts[attribute, default: 0] += 1
            }
            return stringValue
        }
        guard let stringValue = value as? String else {
            nonStringCounts[attribute, default: 0] += 1
            return nil
        }
        if stringValue.isEmpty {
            emptyCounts[attribute, default: 0] += 1
        }
        return stringValue
    }

    private func children(
        of element: AXUIElement,
        fetchErrorCount: inout Int,
        nonArrayCount: inout Int
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard error == .success else {
            fetchErrorCount += 1
            return nil
        }
        if let children = value as? [AXUIElement] {
            return children
        }
        if let array = value as? [Any] {
            return array.map { $0 as! AXUIElement }
        }
        nonArrayCount += 1
        return nil
    }

    private func formatCounts(_ counts: [String: Int]) -> String {
        guard !counts.isEmpty else { return "none" }
        return counts
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
    }
}
