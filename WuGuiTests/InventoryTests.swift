import XCTest
@testable import WuGui

@MainActor
final class InventoryTests: XCTestCase {
    private var directory: URL!
    private var file: URL { directory.appendingPathComponent("inventory.json") }
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testRoundTripPreservesPhotoLocationAndEdits() throws {
        let store = InventoryStore(fileURL: file)
        let place = StoragePlace(name: "抽屉", room: "书房")
        try store.savePlace(place)
        var item = StoredItem(name: " 耳机 ", category: .electronics, quantity: 2, placeID: place.id, photoData: Data([1, 2, 3]))
        try store.saveItem(item)
        item.name = "备用耳机"
        try store.saveItem(item)
        try store.toggleFavorite(item)
        let reopened = InventoryStore(fileURL: file)
        XCTAssertNil(reopened.errorMessage)
        XCTAssertEqual(reopened.items.count, 1)
        XCTAssertEqual(reopened.items.first?.name, "备用耳机")
        XCTAssertEqual(reopened.items.first?.photoData, Data([1, 2, 3]))
        XCTAssertEqual(reopened.items.first?.placeID, place.id)
        XCTAssertTrue(try XCTUnwrap(reopened.items.first).isFavorite)
        XCTAssertEqual(reopened.totalQuantity, 2)
    }

    func testUsedPlaceCannotBeDeletedAndMovingItemAllowsDeletion() throws {
        let store = InventoryStore(fileURL: file)
        let first = StoragePlace(name: "抽屉", room: "书房")
        let second = StoragePlace(name: "盒子", room: "客厅")
        try store.savePlace(first)
        try store.savePlace(second)
        var item = StoredItem(name: "证件袋", placeID: first.id)
        try store.saveItem(item)
        XCTAssertThrowsError(try store.deletePlace(first))
        XCTAssertEqual(store.places.count, 2)
        item.placeID = second.id
        try store.saveItem(item)
        try store.deletePlace(first)
        XCTAssertEqual(store.places.map(\.id), [second.id])
        try store.deleteItem(item)
        try store.deletePlace(second)
        XCTAssertTrue(InventoryStore(fileURL: file).items.isEmpty)
        XCTAssertTrue(InventoryStore(fileURL: file).places.isEmpty)
    }

    func testInvalidInputsDoNotChangeData() throws {
        let store = InventoryStore(fileURL: file)
        XCTAssertThrowsError(try store.saveItem(StoredItem(name: "  ")))
        XCTAssertThrowsError(try store.saveItem(StoredItem(name: "电池", quantity: 0)))
        XCTAssertThrowsError(try store.saveItem(StoredItem(name: "电池", placeID: UUID())))
        XCTAssertThrowsError(try store.savePlace(StoragePlace(name: " ", room: "")))
        try store.savePlace(StoragePlace(name: "抽屉", room: "书房"))
        XCTAssertThrowsError(try store.savePlace(StoragePlace(name: " 抽屉 ", room: "书房 ")))
        try store.savePlace(StoragePlace(name: "抽屉", room: "卧室"))
        XCTAssertEqual(store.places.count, 2)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testCorruptedDataIsPreservedAndCannotBeOverwritten() throws {
        let original = Data("broken json".utf8)
        try original.write(to: file)
        let store = InventoryStore(fileURL: file)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.saveItem(StoredItem(name: "新物品")))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testFailedSaveDoesNotPublishUnsavedItem() throws {
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data([0]).write(to: blocker)
        let store = InventoryStore(fileURL: blocker.appendingPathComponent("inventory.json"))
        XCTAssertThrowsError(try store.saveItem(StoredItem(name: "耳机")))
        XCTAssertTrue(store.items.isEmpty)
    }

    func testNewerFormatIsPreserved() throws {
        let original = try JSONEncoder().encode(InventorySnapshot(version: 2))
        try original.write(to: file)
        let store = InventoryStore(fileURL: file)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.addExamples())
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}
