import SwiftUI
import PhotosUI
import UIKit

struct ItemEditorView: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StoredItem
    private let isEditing: Bool
    @State private var selection: PhotosPickerItem?
    @State private var loadingPhoto = false
    @State private var error: String?
    @State private var addingPlace = false
    @State private var confirmingDiscard = false
    private let initialDraft: StoredItem

    init(item: StoredItem? = nil, placeID: UUID? = nil) {
        let value = item ?? StoredItem(name: "", placeID: placeID)
        _draft = State(initialValue: value)
        initialDraft = value
        isEditing = item != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selection, matching: .images) {
                                ItemThumbnail(item: draft, size: 110)
                                    .overlay(alignment: .bottomTrailing) {
                                        Image(systemName: "camera.fill").font(.system(size: 13)).foregroundStyle(.white)
                                            .padding(9).background(Palette.green, in: Circle()).offset(x: 4, y: 4)
                                    }
                            }.disabled(loadingPhoto).accessibilityLabel("从相册选择物品照片")
                            if loadingPhoto { ProgressView("正在处理照片") }
                            else { Text("添加一张照片，更容易找到").font(.caption).foregroundStyle(Palette.muted) }
                            if draft.photoData != nil { Button("移除照片", role: .destructive) { draft.photoData = nil; selection = nil }.font(.caption) }
                        }
                        Spacer()
                    }.padding(.vertical, 14).listRowBackground(Color.clear)
                }
                Section("基本信息") {
                    TextField("物品名称（必填）", text: $draft.name)
                        .accessibilityIdentifier("itemName")
                    Picker("分类", selection: $draft.category) {
                        ForEach(ItemCategory.allCases) { category in Label(category.rawValue, systemImage: category.symbol).tag(category) }
                    }
                    Stepper(value: $draft.quantity, in: 1...9999) {
                        HStack { Text("数量"); Spacer(); Text("\(draft.quantity) 件").foregroundStyle(Palette.muted).monospacedDigit() }
                    }
                    Toggle("加入常用收藏", isOn: $draft.isFavorite)
                }
                Section {
                    Picker("收纳位置", selection: $draft.placeID) {
                        Text("暂未安排").tag(UUID?.none)
                        ForEach(store.places) { place in Text(place.title).tag(Optional(place.id)) }
                    }
                    Button { addingPlace = true } label: { Label("新建收纳位置", systemImage: "plus.circle") }
                    TextField("具体位置，如：第二层 · 左侧", text: $draft.detail)
                } header: { Text("放在哪里") } footer: { Text("位置可以随时修改；暂时不确定也可以先记下来。") }
                Section("备注") {
                    TextField("颜色、型号、用途，或任何想记住的事", text: $draft.note, axis: .vertical).lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle(isEditing ? "编辑物品" : "记录新物品").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if draft != initialDraft { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.saveItem(draft); dismiss() } catch { self.error = error.localizedDescription }
                    }.fontWeight(.semibold).disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingPhoto)
                        .accessibilityIdentifier("saveItem")
                }
            }
            .sheet(isPresented: $addingPlace) {
                PlaceEditorView { place in draft.placeID = place.id }
            }
            .interactiveDismissDisabled(draft != initialDraft || loadingPhoto)
            .confirmationDialog("放弃尚未保存的修改？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
            }
            .operationError($error)
            .task(id: selection) {
                guard let selection else { return }
                loadingPhoto = true
                defer { loadingPhoto = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else { throw PhotoError.unreadable }
                    try Task.checkCancellation()
                    guard let compressed = await Task.detached(priority: .userInitiated, operation: { Self.compressPhoto(data) }).value else { throw PhotoError.unreadable }
                    try Task.checkCancellation()
                    draft.photoData = compressed
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
            }
        }
    }

    nonisolated private static func compressPhoto(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let ratio = min(1, 1400 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.78)
    }
}

private enum PhotoError: LocalizedError {
    case unreadable
    var errorDescription: String? { "照片读取失败，请选择另一张照片。" }
}

struct PlaceEditorView: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StoragePlace
    @State private var error: String?
    @State private var confirmingDiscard = false
    private let initialDraft: StoragePlace
    private let isEditing: Bool
    var onSave: ((StoragePlace) -> Void)?
    private let symbols = ["archivebox.fill", "cabinet.fill", "shippingbox.fill", "books.vertical.fill", "bed.double.fill", "tv.fill", "sofa.fill", "bag.fill"]

    init(place: StoragePlace? = nil, onSave: ((StoragePlace) -> Void)? = nil) {
        let value = place ?? StoragePlace(name: "", room: "")
        _draft = State(initialValue: value)
        initialDraft = value
        isEditing = place != nil
        self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("位置信息") {
                    TextField("位置名称（必填），如：书桌抽屉", text: $draft.name).accessibilityIdentifier("placeName")
                    TextField("所属房间，如：书房", text: $draft.room).accessibilityIdentifier("placeRoom")
                    TextField("位置说明（可选）", text: $draft.note, axis: .vertical).lineLimit(2...4)
                }
                Section("位置图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button { draft.symbol = symbol } label: {
                                Image(systemName: symbol).font(.system(size: 24)).frame(maxWidth: .infinity).frame(height: 54)
                                    .foregroundStyle(draft.symbol == symbol ? .white : draft.style.color)
                                    .background(draft.symbol == symbol ? draft.style.color : draft.style.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).accessibilityLabel(symbolLabel(symbol)).accessibilityAddTraits(draft.symbol == symbol ? .isSelected : [])
                        }
                    }.padding(.vertical, 8)
                }
                Section("颜色") {
                    HStack(spacing: 16) {
                        ForEach(PlaceStyle.allCases) { style in
                            Button { draft.style = style } label: {
                                Circle().fill(style.color).frame(width: 42, height: 42)
                                    .overlay { if draft.style == style { Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(.white) } }
                            }.buttonStyle(.plain).accessibilityLabel(style.label).accessibilityAddTraits(draft.style == style ? .isSelected : [])
                        }
                    }.padding(.vertical, 6)
                }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle(isEditing ? "编辑位置" : "新建收纳位置").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { if draft != initialDraft { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try store.savePlace(draft); onSave?(draft); dismiss() } catch { self.error = error.localizedDescription }
                    }.fontWeight(.semibold).disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("savePlace")
                }
            }
            .interactiveDismissDisabled(draft != initialDraft)
            .confirmationDialog("放弃尚未保存的修改？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
            }
            .operationError($error)
        }
    }
    private func symbolLabel(_ symbol: String) -> String {
        switch symbol {
        case "archivebox.fill": "抽屉"
        case "cabinet.fill": "柜子"
        case "shippingbox.fill": "收纳箱"
        case "books.vertical.fill": "书架"
        case "bed.double.fill": "床"
        case "tv.fill": "电视柜"
        case "sofa.fill": "沙发"
        default: "收纳袋"
        }
    }
}
