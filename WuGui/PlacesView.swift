import SwiftUI

struct PlacesView: View {
    @EnvironmentObject private var store: InventoryStore
    @State private var addingPlace = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("从房间到抽屉，给每件物品一个确定的位置。")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted).padding(.top, 4)
                if store.places.isEmpty {
                    EmptyInventoryView(symbol: "archivebox", title: "整理，从一个位置开始", message: "例如：书房的书桌抽屉、卧室的衣柜收纳盒。")
                    PrimaryButton(title: "添加收纳位置") { addingPlace = true }
                } else {
                    ForEach(Array(Set(store.places.map(\.room))).sorted(), id: \.self) { room in
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeading(title: room.isEmpty ? "未分房间" : room)
                            ForEach(store.places.filter { $0.room == room }) { place in
                                NavigationLink { PlaceDetailView(placeID: place.id) } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: place.symbol).font(.system(size: 24)).foregroundStyle(place.style.color)
                                            .frame(width: 58, height: 58).background(place.style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(place.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                                            Text("\(store.items(in: place).count) 种物品 · \(store.items(in: place).reduce(0) { $0 + $1.quantity }) 件")
                                                .font(.system(size: 12)).foregroundStyle(Palette.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Palette.muted)
                                    }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 24))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                let unplaced = store.items.filter { $0.placeID == nil }
                if !unplaced.isEmpty {
                    SectionHeading(title: "待安排位置", subtitle: "\(unplaced.count) 种物品")
                    ForEach(unplaced) { item in
                        NavigationLink { ItemDetailView(itemID: item.id) } label: { ItemRow(item: item) }.buttonStyle(.plain)
                    }
                }
            }.padding(22)
        }
        .background(Palette.background).navigationTitle("收纳位置")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingPlace = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加位置")
            }
        }
        .sheet(isPresented: $addingPlace) { PlaceEditorView() }
    }
}

struct PlaceDetailView: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    let placeID: UUID
    @State private var editing = false
    @State private var addingItem = false
    @State private var deleting = false
    @State private var error: String?
    private var place: StoragePlace? { store.places.first { $0.id == placeID } }
    var body: some View {
        Group {
            if let place {
                let items = store.items(in: place).sorted { $0.updatedAt > $1.updatedAt }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: place.symbol).font(.system(size: 32)).foregroundStyle(place.style.color)
                                .frame(width: 70, height: 70).background(place.style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                            Text(place.title).font(.system(size: 26, weight: .bold)).foregroundStyle(Palette.ink)
                            Text("\(items.count) 种物品 · \(items.reduce(0) { $0 + $1.quantity }) 件").font(.subheadline).foregroundStyle(Palette.muted)
                            if !place.note.isEmpty { Text(place.note).font(.subheadline).foregroundStyle(Palette.muted) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(.white, in: RoundedRectangle(cornerRadius: 26))
                        SectionHeading(title: "这里的物品")
                        if items.isEmpty {
                            EmptyInventoryView(symbol: "shippingbox", title: "这个位置还空着", message: "添加物品，或在物品编辑页将已有物品移到这里。")
                        } else {
                            ForEach(items) { item in
                                NavigationLink { ItemDetailView(itemID: item.id) } label: { ItemRow(item: item) }.buttonStyle(.plain)
                            }
                        }
                        PrimaryButton(title: "在这里记录物品") { addingItem = true }
                        if items.isEmpty {
                            Button("删除收纳位置", role: .destructive) { deleting = true }.font(.system(size: 14)).frame(maxWidth: .infinity).padding(8)
                        } else {
                            Text("移动或删除此位置的所有物品后，可以删除位置。")
                                .font(.system(size: 12)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                        }
                    }.padding(22)
                }
            } else { ContentUnavailableView("位置已删除", systemImage: "archivebox") }
        }
        .background(Palette.background).navigationTitle("位置详情").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("编辑") { editing = true } } }
        .sheet(isPresented: $editing) { if let place { PlaceEditorView(place: place) } }
        .sheet(isPresented: $addingItem) { ItemEditorView(placeID: placeID) }
        .confirmationDialog("删除这个收纳位置？", isPresented: $deleting, titleVisibility: .visible) {
            Button("删除位置", role: .destructive) {
                guard let place else { return }
                do { try store.deletePlace(place); dismiss() } catch { self.error = error.localizedDescription }
            }
        }
        .operationError($error)
    }
}
