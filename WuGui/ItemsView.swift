import SwiftUI

struct ItemsView: View {
    @EnvironmentObject private var store: InventoryStore
    @State private var query = ""
    @State private var category: ItemCategory?
    @State private var favoritesOnly = false
    @State private var sortByName = false
    @State private var addingItem = false
    private var filteredItems: [StoredItem] {
        store.items.filter { item in
            (category == nil || item.category == category) && (!favoritesOnly || item.isFavorite) &&
            (query.isEmpty || [item.name, item.note, item.detail, item.category.rawValue, store.place(for: item)?.title ?? ""].contains { $0.localizedStandardContains(query) })
        }.sorted { sortByName ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("搜索物品、位置或备注", text: $query).font(.system(size: 14)).submitLabel(.search)
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }.accessibilityLabel("清除搜索") }
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip("全部", value: nil)
                        ForEach(ItemCategory.allCases) { value in categoryChip(value.rawValue, value: value) }
                    }
                }
                HStack {
                    Text("\(filteredItems.count) 种物品").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    Spacer()
                    Button { favoritesOnly.toggle() } label: {
                        Label("收藏", systemImage: favoritesOnly ? "star.fill" : "star").font(.system(size: 12))
                            .foregroundStyle(favoritesOnly ? Palette.green : Palette.muted)
                    }.accessibilityValue(favoritesOnly ? "仅显示收藏" : "显示全部")
                    Menu {
                        Button { sortByName = false } label: { Label("最近更新", systemImage: sortByName ? "clock" : "checkmark") }
                        Button { sortByName = true } label: { Label("名称排序", systemImage: sortByName ? "checkmark" : "textformat.abc") }
                    } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 13)).padding(.leading, 12) }.accessibilityLabel("排序")
                }
                if filteredItems.isEmpty {
                    EmptyInventoryView(symbol: "magnifyingglass", title: store.items.isEmpty ? "还没有物品记录" : "没有找到相关物品", message: store.items.isEmpty ? "点击右上角 ＋，记下第一件物品。" : "试试其他关键词，或调整分类和收藏筛选。")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            NavigationLink { ItemDetailView(itemID: item.id) } label: { ItemRow(item: item) }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(22)
        }
        .scrollDismissesKeyboard(.interactively).background(Palette.background)
        .navigationTitle("我的物品")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingItem = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加物品")
            }
        }
        .sheet(isPresented: $addingItem) { ItemEditorView() }
    }
    private func categoryChip(_ title: String, value: ItemCategory?) -> some View {
        Button { category = value } label: {
            Text(title).font(.system(size: 13, weight: category == value ? .semibold : .regular))
                .padding(.horizontal, 17).padding(.vertical, 11)
                .foregroundStyle(category == value ? .white : Palette.muted)
                .background(category == value ? Palette.green : .white, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(category == value ? .isSelected : [])
    }
}

struct ItemDetailView: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?
    private var item: StoredItem? { store.items.first { $0.id == itemID } }
    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(spacing: 24) {
                        ItemThumbnail(item: item, size: 156).padding(.top, 20)
                        VStack(spacing: 8) {
                            Text(item.name).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                            Text("\(item.category.rawValue) · \(item.quantity) 件").font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            Label("存放位置", systemImage: "mappin.and.ellipse").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.green)
                            if let place = store.place(for: item) {
                                NavigationLink { PlaceDetailView(placeID: place.id) } label: {
                                    HStack {
                                        Text(place.title).font(.system(size: 20, weight: .semibold))
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13))
                                    }.foregroundStyle(Palette.ink)
                                }
                            } else {
                                Text("尚未设置位置").font(.title3).foregroundStyle(Palette.muted)
                            }
                            if !item.detail.isEmpty { Text(item.detail).font(.subheadline).foregroundStyle(Palette.muted) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
                        if !item.note.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("物品备注", systemImage: "text.alignleft").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.green)
                                Text(item.note).font(.system(size: 15)).foregroundStyle(Palette.ink).textSelection(.enabled)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
                        }
                        VStack(spacing: 8) {
                            Text("记录于 \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            Text("更新于 \(item.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                        PrimaryButton(title: "编辑物品", symbol: "square.and.pencil") { editing = true }
                        Button("删除物品", role: .destructive) { deleting = true }.font(.system(size: 14)).padding(8)
                    }.padding(22)
                }
            } else { ContentUnavailableView("物品已删除", systemImage: "shippingbox") }
        }
        .background(Palette.background).navigationTitle("物品详情").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        do { try store.toggleFavorite(item) } catch { self.error = error.localizedDescription }
                    } label: { Image(systemName: item.isFavorite ? "star.fill" : "star") }
                        .accessibilityLabel(item.isFavorite ? "取消收藏" : "收藏物品")
                }
            }
        }
        .sheet(isPresented: $editing) { if let item { ItemEditorView(item: item) } }
        .confirmationDialog("删除这件物品？", isPresented: $deleting, titleVisibility: .visible) {
            Button("删除物品", role: .destructive) {
                guard let item else { return }
                do { try store.deleteItem(item); dismiss() } catch { self.error = error.localizedDescription }
            }
        } message: { Text("删除后无法恢复。") }
        .operationError($error)
    }
}
