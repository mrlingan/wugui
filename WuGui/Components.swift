import SwiftUI
import UIKit

enum Palette {
    static let background = Color(red: 0.965, green: 0.963, blue: 0.940)
    static let green = Color(red: 0.23, green: 0.38, blue: 0.31)
    static let ink = Color(red: 0.16, green: 0.21, blue: 0.18)
    static let muted = Color(red: 0.48, green: 0.52, blue: 0.48)
    static let sage = Color(red: 0.87, green: 0.91, blue: 0.85)
}

extension PlaceStyle {
    var color: Color {
        switch self {
        case .sage: Palette.green
        case .blue: Color(red: 0.35, green: 0.48, blue: 0.62)
        case .amber: Color(red: 0.65, green: 0.47, blue: 0.24)
        case .rose: Color(red: 0.66, green: 0.43, blue: 0.47)
        }
    }
}

struct ItemThumbnail: View {
    let item: StoredItem
    var size: CGFloat = 60
    var body: some View {
        Group {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 17).fill(Palette.sage.opacity(0.65))
                    .overlay { Image(systemName: item.category.symbol).font(.system(size: size * 0.35)).foregroundStyle(Palette.green) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .accessibilityHidden(true)
    }
}

struct ItemRow: View {
    @EnvironmentObject private var store: InventoryStore
    let item: StoredItem
    var body: some View {
        HStack(spacing: 14) {
            ItemThumbnail(item: item)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    if item.isFavorite { Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(.orange).accessibilityLabel("已收藏") }
                }
                Label(store.place(for: item)?.title ?? "尚未设置位置", systemImage: "mappin")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
                if !item.detail.isEmpty { Text(item.detail).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1) }
            }
            Spacer(minLength: 4)
            Text("×\(item.quantity)").font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted.opacity(0.6))
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 21, weight: .bold)).foregroundStyle(Palette.ink)
            Spacer()
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted) }
        }
    }
}

struct EmptyInventoryView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 35, weight: .light)).foregroundStyle(Palette.green)
                .frame(width: 82, height: 82).background(Palette.sage.opacity(0.55), in: RoundedRectangle(cornerRadius: 25))
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            Text(message).font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 20)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol = "plus"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(.white).background(Palette.green, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct ErrorAlert: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.alert("操作未完成", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了", role: .cancel) {}
        } message: { Text(message ?? "") }
    }
}

extension View {
    func operationError(_ message: Binding<String?>) -> some View { modifier(ErrorAlert(message: message)) }
}
