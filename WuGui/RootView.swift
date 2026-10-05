import SwiftUI

struct RootView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView(selectedTab: $selectedTab) }
                .tabItem { Label("概览", systemImage: "square.grid.2x2.fill") }.tag(0)
            NavigationStack { ItemsView() }
                .tabItem { Label("物品", systemImage: "shippingbox.fill") }.tag(1)
            NavigationStack { PlacesView() }
                .tabItem { Label("位置", systemImage: "mappin.and.ellipse") }.tag(2)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: InventoryStore
    @Binding var selectedTab: Int
    @State private var addingItem = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("让每件物品，都有归处").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                        Text("物归").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Image(systemName: "leaf.fill").font(.system(size: 22)).foregroundStyle(Palette.green)
                        .frame(width: 48, height: 48).background(Palette.sage, in: Circle()).accessibilityHidden(true)
                }
                Button { selectedTab = 1 } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        Text("想找的东西，放在哪里？")
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 12))
                    }.font(.system(size: 14)).foregroundStyle(Palette.muted)
                        .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain)
                overviewCard
                HStack {
                    SectionHeading(title: "我的收纳位置", subtitle: "\(store.places.count) 个位置")
                    Button { selectedTab = 2 } label: { Image(systemName: "arrow.right").font(.system(size: 13)) }
                        .accessibilityLabel("查看所有位置")
                }
                if store.places.isEmpty {
                    Button { selectedTab = 2 } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "archivebox").font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("先为物品准备一个家").font(.system(size: 15, weight: .semibold))
                                Text("添加房间、柜子或收纳盒").font(.system(size: 12)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                        }.foregroundStyle(Palette.green).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.places.prefix(6)) { place in
                                NavigationLink { PlaceDetailView(placeID: place.id) } label: {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Image(systemName: place.symbol).font(.system(size: 25)).foregroundStyle(place.style.color)
                                            .frame(width: 50, height: 50).background(place.style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                                            Text("\(place.room.isEmpty ? "未分房间" : place.room) · \(store.items(in: place).count) 种物品")
                                                .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                                        }
                                    }.frame(width: 146, alignment: .leading).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                SectionHeading(title: "最近记录", subtitle: "随手记，随时找")
                if store.items.isEmpty {
                    VStack(spacing: 12) {
                        EmptyInventoryView(symbol: "shippingbox", title: "从第一件物品开始", message: "记下位置，下次需要时轻松找到。")
                        PrimaryButton(title: "记录第一件物品") { addingItem = true }
                        if store.places.isEmpty {
                            Button("先看看示例") {
                                do { try store.addExamples() } catch { self.error = error.localizedDescription }
                            }.font(.system(size: 13)).padding(.top, 5)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.items.sorted { $0.updatedAt > $1.updatedAt }.prefix(4)) { item in
                            NavigationLink { ItemDetailView(itemID: item.id) } label: { ItemRow(item: item) }.buttonStyle(.plain)
                        }
                    }
                    PrimaryButton(title: "记录新物品") { addingItem = true }
                }
                Text("一物一处 · 生活有序").font(.system(size: 11)).tracking(3).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 20)
        }
        .background(Palette.background).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $addingItem) { ItemEditorView() }
        .operationError($error)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("家的小小物品库").font(.system(size: 20, weight: .semibold))
                    Text("记住位置，留出生活的空间。").font(.system(size: 12)).opacity(0.75)
                }
                Spacer()
                Image(systemName: "shippingbox").font(.system(size: 42, weight: .ultraLight)).rotationEffect(.degrees(-10)).opacity(0.6)
            }
            HStack(spacing: 0) {
                stat("\(store.items.count)", "物品种类")
                stat("\(store.totalQuantity)", "物品总件数")
                stat("\(store.items.filter(\.isFavorite).count)", "常用收藏")
            }
        }
        .foregroundStyle(.white).padding(24).background(Palette.green, in: RoundedRectangle(cornerRadius: 28))
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 11)).opacity(0.75)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
