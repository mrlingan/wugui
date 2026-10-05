import Foundation

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case daily = "日常用品", clothing = "衣物配饰", electronics = "数码电器", documents = "证件文件", books = "书籍文具", tools = "工具杂物", other = "其他"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .daily: "cup.and.saucer.fill"
        case .clothing: "tshirt.fill"
        case .electronics: "headphones"
        case .documents: "doc.text.fill"
        case .books: "books.vertical.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .other: "shippingbox.fill"
        }
    }
}

enum PlaceStyle: String, Codable, CaseIterable, Identifiable {
    case sage, blue, amber, rose
    var id: String { rawValue }
    var label: String {
        switch self { case .sage: "青绿"; case .blue: "雾蓝"; case .amber: "暖黄"; case .rose: "淡粉" }
    }
}

struct StoragePlace: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var room: String
    var note = ""
    var symbol = "archivebox.fill"
    var style: PlaceStyle = .sage
    var title: String { room.isEmpty ? name : "\(room) · \(name)" }
}

struct StoredItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var category: ItemCategory = .daily
    var quantity = 1
    var placeID: UUID?
    var detail = ""
    var note = ""
    var isFavorite = false
    var photoData: Data?
    var createdAt = Date()
    var updatedAt = Date()
}

struct InventorySnapshot: Codable, Equatable {
    var version = 1
    var items: [StoredItem] = []
    var places: [StoragePlace] = []
}

enum InventoryError: LocalizedError {
    case emptyName, invalidQuantity, missingPlace, duplicatePlace, placeInUse, unreadableData, unsupportedVersion
    var errorDescription: String? {
        switch self {
        case .emptyName: "请填写名称。"
        case .invalidQuantity: "数量需要在 1 到 9999 之间。"
        case .missingPlace: "此收纳位置已不存在，请重新选择。"
        case .duplicatePlace: "这个房间里已有同名的收纳位置。"
        case .placeInUse: "请先移动或删除此位置中的物品，再删除位置。"
        case .unreadableData: "无法读取本地记录。原文件已保留，请通过文件共享备份并检查 inventory.json，再重新打开 App。"
        case .unsupportedVersion: "记录来自较新版本，当前版本无法打开。原文件已保留。"
        }
    }
}

struct InventoryRepository {
    let fileURL: URL

    func load() throws -> InventorySnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return InventorySnapshot() }
        let snapshot: InventorySnapshot
        do { snapshot = try JSONDecoder().decode(InventorySnapshot.self, from: Data(contentsOf: fileURL)) }
        catch { throw InventoryError.unreadableData }
        guard snapshot.version == 1 else { throw InventoryError.unsupportedVersion }
        guard Set(snapshot.items.map(\.id)).count == snapshot.items.count,
              Set(snapshot.places.map(\.id)).count == snapshot.places.count,
              snapshot.items.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...9999).contains($0.quantity) }),
              snapshot.places.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              snapshot.items.allSatisfy({ item in item.placeID == nil || snapshot.places.contains(where: { $0.id == item.placeID }) })
        else { throw InventoryError.unreadableData }
        return snapshot
    }

    func save(_ snapshot: InventorySnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
