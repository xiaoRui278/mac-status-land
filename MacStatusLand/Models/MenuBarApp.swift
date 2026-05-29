import CoreGraphics
import Foundation

struct MenuBarApp: Identifiable, Codable {
    let id: String
    let bundleIdentifier: String
    let displayName: String
    var isHidden: Bool
    var originalPosition: CGPoint?
    var screenshotData: Data?

    enum CodingKeys: String, CodingKey {
        case id, bundleIdentifier, displayName, isHidden
        case originalPositionX, originalPositionY
        case screenshotData
    }

    init(bundleIdentifier: String, displayName: String, isHidden: Bool = false) {
        self.id = bundleIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.isHidden = isHidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        displayName = try container.decode(String.self, forKey: .displayName)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        screenshotData = try container.decodeIfPresent(Data.self, forKey: .screenshotData)

        if let x = try container.decodeIfPresent(CGFloat.self, forKey: .originalPositionX),
           let y = try container.decodeIfPresent(CGFloat.self, forKey: .originalPositionY) {
            originalPosition = CGPoint(x: x, y: y)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encodeIfPresent(screenshotData, forKey: .screenshotData)

        if let pos = originalPosition {
            try container.encode(pos.x, forKey: .originalPositionX)
            try container.encode(pos.y, forKey: .originalPositionY)
        }
    }
}
