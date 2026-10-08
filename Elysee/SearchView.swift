import SwiftUI

/// Familles politiques, d'après les codes de nuance que Wikipédia attribue à chaque parti
/// (pas de classement maison : neutralité).
enum Bloc: String, CaseIterable, Identifiable, Hashable {
    case extremeGauche, gauche, ecologistes, centre, droite, souverainistes, extremeDroite, autres
    var id: String { rawValue }

    var title: String {
        switch self {
        case .extremeGauche: "Extrême gauche"
        case .gauche: "Gauche"
        case .ecologistes: "Écologistes"
        case .centre: "Centre"
        case .droite: "Droite"
        case .souverainistes: "Souverainistes"
        case .extremeDroite: "Extrême droite"
        case .autres: "Divers et sans étiquette"
        }
    }

    var symbol: String {
        switch self {
        case .extremeGauche: "flag.fill"
        case .gauche: "rosette"
        case .ecologistes: "leaf.fill"
        case .centre: "circle.circle.fill"
        case .droite: "building.columns.fill"
        case .souverainistes: "shield.fill"
        case .extremeDroite: "flame.fill"
        case .autres: "person.fill.questionmark"
        }
    }

    static func of(_ code: String?) -> Bloc {
        switch code {
        case "LO", "EXG", "NPA": .extremeGauche
        case "LFI", "PCF", "PS", "DVG", "PP", "GRS": .gauche
        case "LE", "LÉ", "GE": .ecologistes
        case "RE", "MoDem", "HOR": .centre
        case "LR", "DVD": .droite
        case "DLF", "LP", "DSV", "UPR": .souverainistes
        case "RN", "REC", "EXD": .extremeDroite
        default: .autres
        }
    }
}

extension Candidate {
    var bloc: Bloc { Bloc.of(colorCode) }
}

extension Store {
    /// Candidats d'une famille : classés d'abord, puis ordre alphabétique.
    func candidates(in bloc: Bloc) -> [Candidate] {
        data.candidats.filter { $0.bloc == bloc }.sorted {
            switch ($0.rank, $1.rank) {
            case let (a?, b?): a < b
            case (_?, nil): true
            case (nil, _?): false
            default: $0.sortName.localizedStandardCompare($1.sortName) == .orderedAscending
            }
        }
    }
}

/// Recherche façon Onde : « Explorer » par famille quand on ne tape rien, résultats + actus quand on tape.
struct SearchView: View {
    @Environment(Store.self) private var store
    @State private var query = ""

    private var typing: Bool { query.trimmingCharacters(in: .whitespaces).count > 1 }

    private var matches: [Candidate] {
        Status.allCases.flatMap { store.candidates($0, matching: query) }
    }

    /// Le mot cherché dans les titres et extraits d'actus de tous les candidats.
    private var said: [FeedView.Item] {
        var seen = Set<URL>()
        return store.data.candidats.flatMap { c in
            c.news.filter { "\($0.title) \($0.excerpt ?? "")".localizedStandardContains(query) }
                .map { FeedView.Item(id: $0.url, candidate: c, title: $0.title, source: $0.source, excerpt: $0.excerpt, date: $0.date, image: $0.image, kind: .actus) }
        }
        .sorted { $0.date > $1.date }
        .filter { seen.insert($0.id).inserted }
        .prefix(12)
        .map(\.self)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if typing {
                    let found = matches, news = said
                    if !found.isEmpty {
                        SectionHeader(title: "Candidats", symbol: "person.fill")
                        VStack(spacing: 14) { ForEach(found) { Row(candidate: $0) } }
                    }
                    if !news.isEmpty {
                        SectionHeader(title: "Dans les actus", symbol: "quote.bubble.fill")
                        VStack(spacing: 16) { ForEach(news) { Strip(item: $0) } }
                    }
                    if found.isEmpty && news.isEmpty {
                        Text("Aucun résultat pour « \(query) ». Jette un œil à ce qui suit.").font(.subheadline).opacity(0.7)
                    }
                }
                if !typing || (matches.isEmpty && said.isEmpty) { explore }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(alignment: .top) { Backdrop() }
        .navigationTitle("Chercher")
        .searchable(text: $query, prompt: "Candidat, parti, sujet d'actu")
        .navigationDestination(for: Bloc.self) { BlocPage(bloc: $0) }
        .animation(.smooth, value: typing)
    }

    @ViewBuilder private var explore: some View {
        SectionHeader(title: "Explorer", symbol: "safari.fill")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Bloc.allCases) { bloc in
                let list = store.candidates(in: bloc)
                if !list.isEmpty { BlocTile(bloc: bloc, candidates: list) }
            }
        }
        Text("Familles d'après les nuances politiques indiquées par Wikipédia pour chaque parti.")
            .font(.caption).foregroundStyle(.secondary)

        let favorites = store.favoriteCandidates
        if !favorites.isEmpty {
            SectionHeader(title: "Mes candidats", symbol: "star.fill")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(favorites) { c in NavigationLink(value: c) { Tile(candidate: c, width: 110) }.buttonStyle(.plain).favoriteMenu(c) }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }

        SectionHeader(title: "Tous les candidats", symbol: "person.3.fill")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 18) {
            ForEach(Status.allCases.flatMap { store.candidates($0) }) { c in
                NavigationLink(value: c) { Tile(candidate: c, width: nil) }.buttonStyle(.plain).favoriteMenu(c)
            }
        }
    }
}

/// Tuile de famille : dégradé à la couleur du premier parti, photos en éventail (comme les thèmes d'Onde).
private struct BlocTile: View {
    let bloc: Bloc
    let candidates: [Candidate]

    var body: some View {
        let color = candidates.first?.deep ?? .gray
        let faces = candidates.filter { $0.photo != nil }.prefix(3)
        NavigationLink(value: bloc) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [candidates.first?.color.mix(with: .black, by: 0.25) ?? .gray, color], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(Array(faces.enumerated()), id: \.offset) { i, c in
                    Remote(url: c.photo?.url)
                        .frame(width: 54, height: 66, alignment: .top)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.25)))
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
                        .rotationEffect(.degrees(Double(i) * 12 - 6))
                        .offset(x: 74 + CGFloat(i) * 22, y: -36 + CGFloat(i) * 8)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: bloc.symbol).font(.subheadline)
                    Text(bloc.title).font(.display(.subheadline, .heavy)).lineLimit(2).minimumScaleFactor(0.8)
                    Text("\(candidates.count)").font(.caption.weight(.bold)).opacity(0.7)
                }
                .padding(14)
                .frame(maxWidth: 110, alignment: .leading)
            }
            .foregroundStyle(.white)
            .frame(height: 128)
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bloc.title), \(candidates.count) candidats")
    }
}

/// Ligne de résultat : portrait, nom, pastille du parti, score.
private struct Row: View {
    let candidate: Candidate

    var body: some View {
        let c = candidate
        NavigationLink(value: c) {
            HStack(spacing: 14) {
                Remote(url: c.photo?.url)
                    .frame(width: 64, height: 76, alignment: .top)
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottom) { Rectangle().fill(c.color).frame(height: 3) }
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(c.name).font(.headline).lineLimit(1)
                    PartyBadge(candidate: c)
                    Text(c.primary ?? c.status.badge).font(.caption).opacity(0.6)
                }
                Spacer(minLength: 0)
                if let avg = c.poll?.avg {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(avg.percent).font(.display(.headline, .black)).monospacedDigit()
                        if let rank = c.rank { Text(rank.ordinal).font(.caption2.weight(.bold)).opacity(0.6) }
                    }
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).opacity(0.4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .favoriteMenu(c)
    }
}

/// Page d'une famille : grande en-tête colorée puis les candidats.
private struct BlocPage: View {
    let bloc: Bloc
    @Environment(Store.self) private var store

    var body: some View {
        let list = store.candidates(in: bloc)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("FAMILLE POLITIQUE", systemImage: bloc.symbol).font(.caption.weight(.bold)).tracking(1).opacity(0.7)
                    Text(bloc.title).font(.display(.largeTitle, .black))
                    Text("\(list.count) candidat\(list.count > 1 ? "s" : "")").font(.subheadline).opacity(0.7)
                }
                .padding(.top, 8)
                VStack(spacing: 14) { ForEach(list) { Row(candidate: $0) } }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) { Backdrop(color: list.first?.color) }
        .navigationTitle("")
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }
}
