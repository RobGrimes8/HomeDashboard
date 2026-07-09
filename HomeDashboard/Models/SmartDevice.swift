import Foundation

enum DeviceKind: String, Codable {
    case light
    case lightGroup
    case speaker
    case switchDevice = "switch"
    case thermostat
    case unknown
}

struct SmartDevice: Codable, Equatable {
    let id: String
    let name: String
    let kind: DeviceKind
    let room: String?
    var isOn: Bool
    var brightness: Int?
    var volume: Int?
    var nowPlaying: String?
    var isReachable: Bool

    init(
        id: String,
        name: String,
        kind: DeviceKind,
        room: String? = nil,
        isOn: Bool = false,
        brightness: Int? = nil,
        volume: Int? = nil,
        nowPlaying: String? = nil,
        isReachable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.room = room
        self.isOn = isOn
        self.brightness = brightness
        self.volume = volume
        self.nowPlaying = nowPlaying
        self.isReachable = isReachable
    }
}

struct SonosFavorite: Equatable {
    let title: String
    let uri: String
    let metadata: String
    /// Sonos favorite reference (e.g. FV:2/3) when URI must be resolved via Browse.
    let objectID: String?
    // TEMP DEBUG — remove after favorites playback is fixed
    let elementTag: String
    let itemID: String
    let openingTag: String
    let rawBody: String

    init(
        title: String,
        uri: String,
        metadata: String,
        objectID: String? = nil,
        elementTag: String = "",
        itemID: String = "",
        openingTag: String = "",
        rawBody: String = ""
    ) {
        self.title = title
        self.uri = uri
        self.metadata = metadata
        self.objectID = objectID
        self.elementTag = elementTag
        self.itemID = itemID
        self.openingTag = openingTag
        self.rawBody = rawBody
    }

    /// Plain-text dump of everything we parsed from the favorites list.
    var debugSummary: String {
        let decodedMetadata = SonosFavoriteDebug.decodeHTMLEntities(metadata)
        return """
        TITLE: \(title)
        ELEMENT: \(elementTag.isEmpty ? "(unknown)" : elementTag)
        ITEM ID: \(itemID.isEmpty ? "(empty)" : itemID)
        OBJECT ID: \(objectID ?? "(nil)")
        URI: \(uri.isEmpty ? "(empty)" : uri)
        OPENING TAG: \(openingTag.isEmpty ? "(empty)" : openingTag)
        RAW BODY:
        \(rawBody.isEmpty ? "(empty)" : rawBody)
        METADATA (escaped, stored):
        \(metadata.isEmpty ? "(empty)" : metadata)
        METADATA (decoded):
        \(decodedMetadata.isEmpty ? "(empty)" : decodedMetadata)
        """
    }
}

enum SonosFavoriteDebug {
    static func decodeHTMLEntities(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

struct DashboardSnapshot {
    let lightGroups: [SmartDevice]
    let lights: [SmartDevice]
    let speakers: [SmartDevice]
    let lastUpdated: Date
    let errorMessage: String?

    var allDevices: [SmartDevice] {
        return lightGroups + lights + speakers
    }

    static var empty: DashboardSnapshot {
        return DashboardSnapshot(lightGroups: [], lights: [], speakers: [], lastUpdated: Date(), errorMessage: nil)
    }
}
