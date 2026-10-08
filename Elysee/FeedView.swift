import SwiftUI

/// Le fil, façon Onde : grand titre, filtres en pastilles, une carte à la une puis des bandeaux illustrés.
struct FeedView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case actus = "Actus", videos = "Vidéos", podcasts = "Podcasts", posts = "Bluesky"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .actus: "newspaper.fill"
            case .videos: "play.rectangle.fill"
            case .podcasts: "headphones"
            case .posts: "cloud.fill"
            }
        }
    }

    struct Item: Identifiable {
        let id: URL
        let candidate: Candidate
        let title: String
        let source: String?
        let excerpt: String?
        let date: Date
        let image: URL?
        let kind: Kind
    }

    @Environment(Store.self) private var store
    @State private var kind = Kind.actus
    @State private var only: Candidate?

    private var items: [Item] {
        var seen = Set<URL>()
        let pool = only.map { [$0] } ?? store.data.candidats
        return pool.flatMap { c -> [Item] in
            switch kind {
            case .actus: c.news.map { Item(id: $0.url, candidate: c, title: $0.title, source: $0.source, excerpt: $0.excerpt, date: $0.date, image: $0.image, kind: kind) }
            case .videos: c.videos.map { Item(id: $0.url, candidate: c, title: $0.title, source: $0.channel, excerpt: nil, date: $0.date, image: $0.thumbnail, kind: kind) }
            case .podcasts: c.podcasts.map { Item(id: $0.url, candidate: c, title: $0.title, source: $0.show, excerpt: $0.duration.map { "\($0) min" }, date: $0.date, image: $0.artwork, kind: kind) }
            case .posts: (c.posts ?? []).map { Item(id: $0.url, candidate: c, title: $0.text, source: "Bluesky", excerpt: nil, date: $0.date, image: $0.image, kind: kind) }
            }
        }
        .sorted { $0.date > $1.date }
        .filter { seen.insert($0.id).inserted }
        .prefix(60)
        .map(\.self)
    }

    var body: some View {
        let list = items
        let feature = list.first { $0.image != nil } ?? list.first
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Ce qui se dit sur les candidats")
                    Text("Le fil").font(.display(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Chips(kind: $kind)
                    People(selected: $only, candidates: store.ranked + store.data.candidats.filter { $0.rank == nil && $0.status != .pressenti }.sorted { $0.sortName < $1.sortName })
                }

                if let feature {
                    Link(destination: feature.id) { Feature(item: feature) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                }

                LazyVStack(spacing: 18) {
                    ForEach(list.filter { $0.id != feature?.id }) { item in
                        if item.kind == .videos {
                            Link(destination: item.id) { Feature(item: item, compact: true) }.buttonStyle(.plain)
                        } else {
                            Strip(item: item)
                        }
                    }
                }
                .padding(.horizontal, 20)

                if list.isEmpty {
                    ContentUnavailableView("Rien pour l'instant", systemImage: kind.symbol, description: Text("Aucun contenu récent dans cette catégorie."))
                }
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) { Backdrop(color: (only ?? feature?.candidate)?.color) }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .refreshable { await store.refresh() }
        .animation(.snappy, value: kind)
        .animation(.snappy, value: only)
    }
}

/// Pastilles de type de contenu (comme la barre d'humeurs d'Onde).
private struct Chips: View {
    @Binding var kind: FeedView.Kind

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(FeedView.Kind.allCases) { k in
                    Button { kind = k } label: {
                        Label(k.rawValue, systemImage: k.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .foregroundStyle(k == kind ? Color.canvas : Color.primary)
                            .background(k == kind ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.primary.opacity(0.1)), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(k == kind ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .sensoryFeedback(.selection, trigger: kind)
    }
}

/// Filtre par candidat : rangée d'avatars, toucher à nouveau pour tout revoir.
private struct People: View {
    @Binding var selected: Candidate?
    let candidates: [Candidate]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(candidates) { c in
                    Button { selected = selected == c ? nil : c } label: {
                        VStack(spacing: 4) {
                            Avatar(candidate: c, size: 52)
                                .overlay(Circle().strokeBorder(c.color, lineWidth: selected == c ? 3 : 0).padding(-4))
                                .padding(4)
                                .opacity(selected == nil || selected == c ? 1 : 0.4)
                            Text(c.sortName).font(.caption2.weight(.semibold)).lineLimit(1).frame(width: 64)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.name)
                    .accessibilityAddTraits(selected == c ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

/// Grande carte image + légende dans la couleur sombre du parti.
private struct Feature: View {
    let item: FeedView.Item
    var compact = false

    var body: some View {
        let c = item.candidate
        VStack(alignment: .leading, spacing: 0) {
            Color.primary.opacity(0.06)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .top) { Remote(url: item.image ?? c.photo?.url) }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, c.deep], startPoint: .top, endPoint: .bottom).frame(height: 80)
                }
                .overlay {
                    if item.kind == .videos {
                        Image(systemName: "play.fill").font(.title).foregroundStyle(.white)
                            .frame(width: 60, height: 60).glassEffect(.regular, in: .circle)
                    }
                }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Avatar(candidate: c, size: 24)
                    Text(c.name.uppercased()).font(.caption2.weight(.bold)).tracking(1.1)
                    PartyMark(candidate: c, size: 13)
                    Spacer()
                    Text(item.date.short).font(.caption2.weight(.semibold)).opacity(0.7)
                }
                Text(item.title).font(compact ? .headline : .display(.title3, .heavy)).lineLimit(compact ? 2 : 4)
                if !compact, let excerpt = item.excerpt { Text(excerpt).font(.subheadline).opacity(0.8).lineLimit(3) }
                if let source = item.source { Text(source).font(.caption.weight(.semibold)).opacity(0.65) }
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(c.deep)
        }
        .foregroundStyle(.white)
        .clipShape(.rect(cornerRadius: compact ? 24 : 30, style: .continuous))
        .shadow(color: c.color.opacity(0.3), radius: compact ? 14 : 24, y: 10)
    }
}

/// Bandeau : vignette (image de l'article, pochette ou photo du candidat) + texte.
private struct Strip: View {
    let item: FeedView.Item

    var body: some View {
        let c = item.candidate
        Link(destination: item.id) {
            HStack(alignment: .top, spacing: 14) {
                Remote(url: item.image ?? c.photo?.url)
                    .frame(width: 92, height: 92, alignment: .top)
                    .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if item.image != nil { Avatar(candidate: c, size: 28).overlay(Circle().strokeBorder(Color.canvas, lineWidth: 2)).offset(x: 6, y: 6) }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text([c.name, item.source].compactMap(\.self).joined(separator: " · ").uppercased())
                        .font(.caption2.weight(.bold)).tracking(1).opacity(0.55).lineLimit(1)
                    Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(3).multilineTextAlignment(.leading)
                    Text([item.date.short, item.kind == .podcasts ? item.excerpt : nil].compactMap(\.self).joined(separator: " · "))
                        .font(.caption).opacity(0.55)
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
