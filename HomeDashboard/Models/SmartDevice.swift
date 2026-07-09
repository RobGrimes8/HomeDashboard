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
    var isReachable: Bool

    init(
        id: String,
        name: String,
        kind: DeviceKind,
        room: String? = nil,
        isOn: Bool = false,
        brightness: Int? = nil,
        volume: Int? = nil,
        isReachable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.room = room
        self.isOn = isOn
        self.brightness = brightness
        self.volume = volume
        self.isReachable = isReachable
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
