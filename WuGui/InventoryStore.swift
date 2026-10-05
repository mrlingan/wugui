import Foundation
import Combine

@MainActor
final class InventoryStore: ObservableObject {
    @Published private(set) var snapshot = InventorySnapshot()
    @Published var errorMessage: String?
    private let repository: InventoryRepository
    private var canWrite = true
    var items: [StoredItem] { snapshot.items }
    var places: [StoragePlace] { snapshot.places }
    var totalQuantity: Int { items.reduce(0) { $0 + $1.quantity } }

    init(fileURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        repository = InventoryRepository(fileURL: fileURL ?? documents.appendingPathComponent("inventory.json"))
        do { snapshot = try repository.load() }
        catch { canWrite = false; errorMessage = error.localizedDescription }
    }

    func place(for item: StoredItem) -> StoragePlace? { places.first { $0.id == item.placeID } }
    func items(in place: StoragePlace) -> [StoredItem] { items.filter { $0.placeID == place.id } }

    private func commit(_ next: InventorySnapshot) throws {
        guard canWrite else { throw InventoryError.unreadableData }
        try repository.save(next)
        snapshot = next
    }

    func saveItem(_ input: StoredItem) throws {
        var item = input
        item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.name.isEmpty else { throw InventoryError.emptyName }
        guard (1...9999).contains(item.quantity) else { throw InventoryError.invalidQuantity }
        if let id = item.placeID, !places.contains(where: { $0.id == id }) { throw InventoryError.missingPlace }
        item.updatedAt = Date()
        var next = snapshot
        if let index = next.items.firstIndex(where: { $0.id == item.id }) { next.items[index] = item }
        else { next.items.append(item) }
        try commit(next)
    }

    func deleteItem(_ item: StoredItem) throws {
        var next = snapshot
        next.items.removeAll { $0.id == item.id }
        try commit(next)
    }

    func toggleFavorite(_ item: StoredItem) throws {
        guard var current = items.first(where: { $0.id == item.id }) else { return }
        current.isFavorite.toggle()
        try saveItem(current)
    }

    func savePlace(_ input: StoragePlace) throws {
        var place = input
        place.name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        place.room = place.room.trimmingCharacters(in: .whitespacesAndNewlines)
        place.note = place.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.name.isEmpty else { throw InventoryError.emptyName }
        guard !places.contains(where: { $0.id != place.id && $0.name.localizedCaseInsensitiveCompare(place.name) == .orderedSame && $0.room.localizedCaseInsensitiveCompare(place.room) == .orderedSame }) else { throw InventoryError.duplicatePlace }
        var next = snapshot
        if let index = next.places.firstIndex(where: { $0.id == place.id }) { next.places[index] = place }
        else { next.places.append(place) }
        try commit(next)
    }

    func deletePlace(_ place: StoragePlace) throws {
        guard items(in: place).isEmpty else { throw InventoryError.placeInUse }
        var next = snapshot
        next.places.removeAll { $0.id == place.id }
        try commit(next)
    }

    func addExamples() throws {
        guard items.isEmpty && places.isEmpty else { return }
        let study = StoragePlace(name: "书桌抽屉", room: "书房", note: "桌面右侧的第一层抽屉", symbol: "archivebox.fill", style: .sage)
        let bedroom = StoragePlace(name: "衣柜收纳盒", room: "卧室", symbol: "cabinet.fill", style: .rose)
        let living = StoragePlace(name: "电视柜", room: "客厅", symbol: "tv.fill", style: .blue)
        var next = snapshot
        next.places = [study, bedroom, living]
        next.items = [
            StoredItem(name: "降噪耳机", category: .electronics, placeID: study.id, detail: "第一层 · 左侧", note: "充电线一起放在收纳袋里", isFavorite: true),
            StoredItem(name: "旅行证件袋", category: .documents, placeID: bedroom.id, detail: "蓝色收纳盒", isFavorite: true),
            StoredItem(name: "备用电池", category: .tools, quantity: 8, placeID: living.id, detail: "右侧抽屉"),
            StoredItem(name: "日常手账", category: .books, placeID: study.id, detail: "第二层", note: "和黑色中性笔放在一起")
        ]
        try commit(next)
    }
}
