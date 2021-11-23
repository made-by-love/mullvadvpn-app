//
//  PreferencesViewModel.swift
//  MullvadVPN
//
//  Created by pronebird on 11/10/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit

enum CustomDNSPrecondition {
    /// Custom DNS can be enabled
    case satisfied

    /// Custom DNS cannot be enabled as it would conflict with other settings.
    case conflictsWithOtherSettings

    /// No valid DNS server entries.
    case emptyDNSDomains

    /// Returns localized description explaining how to enable Custom DNS.
    func localizedDescription(isEditing: Bool) -> String? {
        return attributedLocalizedDescription(
            isEditing: isEditing,
            preferredFont: UIFont.systemFont(ofSize: UIFont.systemFontSize)
        )?.string
    }

    /// Returns attributed localized description explaining how to enable Custom DNS.
    func attributedLocalizedDescription(isEditing: Bool, preferredFont: UIFont) -> NSAttributedString? {
        switch self {
        case .satisfied:
            return nil

        case .emptyDNSDomains:
            if isEditing {
                return NSAttributedString(markdownString: NSLocalizedString(
                    "CUSTOM_DNS_NO_DNS_ENTRIES_EDITING_ON_FOOTNOTE",
                    tableName: "Preferences",
                    value: "To enable this setting, add at least one server.",
                    comment: "Foot note displayed if there are no DNS entries and table view is in editing mode."
                ), font: preferredFont)
            } else {
                return NSAttributedString(markdownString: NSLocalizedString(
                    "CUSTOM_DNS_NO_DNS_ENTRIES_EDITING_OFF_FOOTNOTE",
                    tableName: "Preferences",
                    value: "Tap **Edit** to add at least one DNS server.",
                    comment: "Foot note displayed if there are no DNS entries, but table view is not in editing mode."
                ), font: preferredFont)
            }

        case .conflictsWithOtherSettings:
            return NSAttributedString(markdownString: NSLocalizedString(
                "CUSTOM_DNS_DISABLE_ADTRACKER_BLOCKING_FOOTNOTE",
                tableName: "Preferences",
                value: "Disable **Block ads** and **Block trackers** to activate this setting.",
                comment: "Foot note displayed when custom DNS cannot be enabled, because ad/tracker blockers features should be disabled first."
            ), font: preferredFont)
        }
    }
}

struct DNSServerEntry: Equatable, Hashable {
    var identifier = UUID()
    var address: String
}

struct PreferencesViewModel: Equatable {
    private(set) var blockAdvertising: Bool
    private(set) var blockTracking: Bool
    private(set) var enableCustomDNS: Bool
    var customDNSDomains: [DNSServerEntry]

    mutating func setBlockAdvertising(_ newValue: Bool) {
        blockAdvertising = newValue
        enableCustomDNS = false
    }

    mutating func setBlockTracking(_ newValue: Bool) {
        blockTracking = newValue
        enableCustomDNS = false
    }

    mutating func setEnableCustomDNS(_ newValue: Bool) {
        blockTracking = false
        blockAdvertising = false
        enableCustomDNS = newValue
    }

    /// Precondition for enabling Custom DNS.
    var customDNSPrecondition: CustomDNSPrecondition {
        if blockAdvertising || blockTracking {
            return .conflictsWithOtherSettings
        } else {
            let hasValidDNSDomains = customDNSDomains.contains { entry in
                return AnyIPAddress(entry.address) != nil
            }

            if hasValidDNSDomains {
                return .satisfied
            } else {
                return .emptyDNSDomains
            }
        }
    }

    /// Effective state of the custom DNS setting.
    var effectiveEnableCustomDNS: Bool {
        return customDNSPrecondition == .satisfied && enableCustomDNS
    }

    init(from dnsSettings: DNSSettings = DNSSettings()) {
        blockAdvertising = dnsSettings.blockAdvertising
        blockTracking = dnsSettings.blockTracking
        enableCustomDNS = dnsSettings.enableCustomDNS
        customDNSDomains = dnsSettings.customDNSDomains.map { ipAddress in
            return DNSServerEntry(identifier: UUID(), address: "\(ipAddress)")
        }
    }

    /// Produce merged view model keeping entry `identifier` for matching DNS entries.
    func merged(_ other: PreferencesViewModel) -> PreferencesViewModel {
        var mergedViewModel = PreferencesViewModel()

        mergedViewModel.blockAdvertising = other.blockAdvertising
        mergedViewModel.blockTracking = other.blockTracking
        mergedViewModel.enableCustomDNS = other.enableCustomDNS

        var oldDNSDomains = customDNSDomains
        for otherEntry in other.customDNSDomains {
            let sameEntryIndex = oldDNSDomains.firstIndex { entry in
                return entry.address == otherEntry.address
            }

            if let sameEntryIndex = sameEntryIndex {
                let sourceEntry = oldDNSDomains[sameEntryIndex]

                mergedViewModel.customDNSDomains.append(sourceEntry)
                oldDNSDomains.remove(at: sameEntryIndex)
            } else {
                mergedViewModel.customDNSDomains.append(otherEntry)
            }
        }

        return mergedViewModel
    }

    /// Sanitize custom DNS entries.
    mutating func sanitizeCustomDNSEntries() {
        // Santize DNS domains, drop invalid entries.
        customDNSDomains = customDNSDomains.compactMap { entry in
            if let canonicalAddress = AnyIPAddress(entry.address) {
                var newEntry = entry
                newEntry.address = "\(canonicalAddress)"
                return newEntry
            } else {
                return nil
            }
        }

        // Toggle off custom DNS when no domains specified.
        if customDNSDomains.isEmpty {
            enableCustomDNS = false
        }
    }

    func dnsEntry(entryIdentifier: UUID) -> DNSServerEntry? {
        return customDNSDomains.first { entry in
            return entry.identifier == entryIdentifier
        }
    }

    /// Returns an index of entry in `customDNSDomains`, otherwise `nil`.
    func indexOfDNSEntry(entryIdentifier: UUID) -> Int? {
        return customDNSDomains.firstIndex { entry in
            return entry.identifier == entryIdentifier
        }
    }

    /// Update the address for the DNS entry with the given UUID.
    mutating func updateDNSEntry(entryIdentifier: UUID, newAddress: String) {
        guard let index = indexOfDNSEntry(entryIdentifier: entryIdentifier) else { return }

        var entry = customDNSDomains[index]
        entry.address = newAddress
        customDNSDomains[index] = entry
    }

    /// Converts view model into `DNSSettings`.
    func asDNSSettings() -> DNSSettings {
        var dnsSettings = DNSSettings()
        dnsSettings.blockAdvertising = blockAdvertising
        dnsSettings.blockTracking = blockTracking
        dnsSettings.enableCustomDNS = enableCustomDNS
        dnsSettings.customDNSDomains = customDNSDomains.compactMap { entry in
            return AnyIPAddress(entry.address)
        }
        return dnsSettings
    }

    /// Returns true if the given string is empty or a valid IP address.
    func validateDNSDomainUserInput(_ string: String) -> Bool {
        return string.isEmpty || AnyIPAddress(string) != nil
    }
}
