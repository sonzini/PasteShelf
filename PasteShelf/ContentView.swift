import ServiceManagement
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var state: PanelState
    let onPick: (ClipItem, _ plain: Bool) -> Void
    let onAbout: () -> Void

    @State private var hovered: UUID?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @FocusState private var searchFocused: Bool

    private var visible: (favs: [ClipItem], hist: [ClipItem]) { store.visible(search: state.search) }
    private var flat: [ClipItem] { let v = visible; return v.favs + v.hist }
    private var selectedItem: ClipItem? { flat.indices.contains(state.selected) ? flat[state.selected] : nil }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if flat.isEmpty {
                emptyState
            } else {
                list
            }
            if store.showPreview, let item = selectedItem {
                Divider()
                preview(item)
            }
            Divider()
            footer
        }
        .frame(width: 420, height: store.showPreview ? 600 : 480)
        .onAppear(perform: reset)
        .onChange(of: state.openCount) { _, _ in reset() }
        .onChange(of: state.search) { _, _ in state.selected = 0 }
    }

    private func reset() {
        state.search = ""
        state.selected = 0
        launchAtLogin = SMAppService.mainApp.status == .enabled
        DispatchQueue.main.async { searchFocused = true }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L("Search…"), text: $state.search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
        }
        .padding(10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard").font(.largeTitle).foregroundStyle(.tertiary)
            Text(state.search.isEmpty ? L("Nothing copied yet") : L("No results"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        let v = visible
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !v.favs.isEmpty {
                        sectionHeader(L("Favorites"), icon: "star.fill")
                        ForEach(Array(v.favs.enumerated()), id: \.element.id) { i, item in
                            row(item, index: i)
                        }
                    }
                    if !v.hist.isEmpty {
                        sectionHeader(L("History"), icon: "clock")
                        ForEach(Array(v.hist.enumerated()), id: \.element.id) { i, item in
                            row(item, index: v.favs.count + i)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: state.selected) { _, newValue in
                let items = flat
                if items.indices.contains(newValue) { proxy.scrollTo(items[newValue].id) }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func row(_ item: ClipItem, index: Int) -> some View {
        let isSelected = index == state.selected
        let isHovered = hovered == item.id
        let fg: Color = isSelected ? .white : .primary
        let secondary: Color = isSelected ? .white.opacity(0.8) : .secondary

        return HStack(spacing: 8) {
            if item.isImage {
                if let img = store.image(for: item) {
                    let height: CGFloat = 36
                    let aspect = img.size.height > 0 ? img.size.width / img.size.height : 1
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: min(90, height * aspect), height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(item.text)
                    .font(.system(size: 12))
                    .foregroundStyle(secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(previewLine(item.text))
                    .lineLimit(2)
                    .font(.system(size: 12.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(fg)
            }

            if index < 9 && !isHovered {
                Text("⌘\(index + 1)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(secondary)
            }
            if isHovered || isSelected || item.favorite {
                Button { store.toggleFavorite(item) } label: {
                    Image(systemName: item.favorite ? "star.fill" : "star")
                        .foregroundStyle(item.favorite ? Color.yellow : secondary)
                }
                .buttonStyle(.plain)
                .help(item.favorite ? L("Remove from Favorites") : L("Add to Favorites"))
                .accessibilityLabel(item.favorite ? L("Remove from Favorites") : L("Add to Favorites"))
            }
            if isHovered || isSelected {
                Button { store.delete(item) } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(secondary)
                }
                .buttonStyle(.plain)
                .help(L("Delete"))
                .accessibilityLabel(L("Delete"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.07) : .clear))
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { inside in
            hovered = inside ? item.id : (hovered == item.id ? nil : hovered)
            if inside { state.selected = index }
        }
        .onTapGesture {
            onPick(item, NSEvent.modifierFlags.contains(.option))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .id(item.id)
    }

    private func preview(_ item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if item.isImage, let img = store.image(for: item) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(item.text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(info(item))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 120)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle(L("Paste on select"), isOn: $store.autoPaste)
                .toggleStyle(.checkbox)
                .font(.caption)
            Text(L("⌥ = plain text"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                store.showPreview.toggle()
            } label: {
                Image(systemName: store.showPreview ? "eye" : "eye.slash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(store.showPreview ? L("Hide Preview") : L("Show Preview"))
            .accessibilityLabel(store.showPreview ? L("Hide Preview") : L("Show Preview"))

            Menu {
                Toggle(L("Launch at Login"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                Divider()
                Button(L("Clear History (Keeps Favorites)")) { store.clearHistory() }
                Divider()
                Text(L("Open with ⌘⇧V"))
                Button(L("About PasteShelf")) { onAbout() }
                Button(L("Quit PasteShelf")) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(L("Settings"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func previewLine(_ text: String) -> String {
        let collapsed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.count > 300 ? String(collapsed.prefix(300)) + "…" : collapsed
    }

    private func info(_ item: ClipItem) -> String {
        let when = RelativeDateTimeFormatter().localizedString(for: item.date, relativeTo: Date())
        if item.isImage { return "\(item.text) · \(when)" }
        let lines = item.text.split(separator: "\n", omittingEmptySubsequences: false).count
        var parts = [L("%d characters", item.text.count)]
        if lines > 1 { parts.append(L("%d lines", lines)) }
        if item.hasFormat { parts.append(L("formatted")) }
        parts.append(when)
        return parts.joined(separator: " · ")
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("PasteShelf: could not change Launch at Login: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
