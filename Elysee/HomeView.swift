import SwiftUI

// MARK: - Accueil

/// Accueil façon Onde : carrousel des premiers des sondages, classement, puis rangées par statut.
struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var heroID: String?
    @State private var showSettings = false

    var body: some View {
        let heroes = Array(store.ranked.prefix(6))
        let current = heroes.first { $0.id == heroID } ?? heroes.first
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header.padding(.horizontal, 20)

                let favorites = store.favoriteCandidates
                if !favorites.isEmpty {
                    TileRow(title: "Mes candidats", symbol: "star.fill", count: favorites.count, candidates: favorites)
                }

                if !heroes.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "En tête des sondages", symbol: "chart.bar.fill").padding(.horizontal, 20)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 14) {
                                ForEach(heroes) { c in
                                    NavigationLink(value: c) { HeroCard(candidate: c) }
                                        .buttonStyle(.plain)
                                        .containerRelativeFrame(.horizontal) { w, _ in w - 56 }
                                        .scrollTransition { v, p in v.scaleEffect(p.isIdentity ? 1 : 0.93).opacity(p.isIdentity ? 1 : 0.6) }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $heroID)
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                        .scrollClipDisabled()
                    }
                    Ranking(candidates: store.ranked, meta: store.data.polls).padding(.horizontal, 20)
                }

                ForEach(Status.allCases, id: \.self) { status in
                    let list = store.candidates(status)
                    if !list.isEmpty { TileRow(title: status.title, count: list.count, candidates: list) }
                }

                Footer().padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) { Backdrop(color: current?.color) }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .refreshable { await store.refresh() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        let first = "2027-04-18".isoDay!
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: first).day ?? 0)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    HStack(spacing: 12) {
                        Tricolore(height: 26)
                        Text("Élysée 2027").font(.display(.largeTitle, .black)).accessibilityAddTraits(.isHeader)
                    }
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.headline).frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Réglages")
            }
            HStack(spacing: 10) {
                Text("J-\(days)").font(.display(.title3, .black))
                    .foregroundStyle(LinearGradient(colors: [.bleu.mix(with: .primary, by: 0.25), .rouge], startPoint: .leading, endPoint: .trailing))
                Text("1er tour le 18 avril · 2nd tour le 2 mai").font(.subheadline.weight(.semibold)).opacity(0.7)
            }
            .padding(.top, 6)
        }
    }
}

/// Grande carte : portrait, puis légende dans la couleur sombre du parti.
private struct HeroCard: View {
    let candidate: Candidate

    var body: some View {
        let c = candidate
        VStack(alignment: .leading, spacing: 0) {
            Color.white.opacity(0.06)
                .aspectRatio(0.95, contentMode: .fit)
                .overlay(alignment: .top) { Remote(url: c.photo?.url) }
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, c.deep], startPoint: .top, endPoint: .bottom).frame(height: 120)
                }
                .overlay(alignment: .topLeading) {
                    if let rank = c.rank {
                        Text(rank.ordinal)
                            .font(.display(.subheadline, .black))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .glassEffect()
                            .padding(14)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if c.partyLogo != nil {
                        PartyMark(candidate: c, size: 26)
                            .frame(width: 46, height: 46)
                            .background(c.deep.opacity(0.75), in: .circle)
                            .glassEffect(.regular, in: .circle)
                            .padding(14)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    PartyMark(candidate: c, size: 14)
                    Text((c.party ?? "Sans étiquette").uppercased()).font(.caption2.weight(.bold)).tracking(1.2).lineLimit(1)
                }
                .opacity(0.8)
                Text(c.name).font(.display(.title2, .black)).lineLimit(1).minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline) {
                    if let avg = c.poll?.avg {
                        Text(avg.percent).font(.display(.title, .black)).monospacedDigit()
                        Text("d'intentions de vote").font(.caption.weight(.semibold)).opacity(0.7)
                    }
                    Spacer()
                    Label("Fiche", systemImage: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .foregroundStyle(c.deep)
                        .background(.white, in: .capsule)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(c.deep)
        }
        .foregroundStyle(.white)
        .clipShape(.rect(cornerRadius: 30, style: .continuous))
        .shadow(color: c.color.opacity(0.35), radius: 28, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(c.rank?.ordinal ?? ""), \(c.name), \(c.party ?? ""), \(c.poll?.avg?.percent ?? "")")
        .accessibilityAddTraits(.isButton)
    }
}

/// Classement complet : barres à la couleur du parti, fourchette min–max des hypothèses.
private struct Ranking: View {
    let candidates: [Candidate]
    let meta: PollMeta?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let top = candidates.compactMap(\.poll?.max).max() ?? 40
        Card(title: "Intentions de vote", systemImage: "chart.bar.fill") {
            VStack(spacing: 14) {
                ForEach(candidates) { c in
                    NavigationLink(value: c) {
                        HStack(spacing: 12) {
                            Text("\(c.rank ?? 0)").font(.display(.caption, .black)).opacity(0.5).frame(width: 20)
                            Avatar(candidate: c, size: 36)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(c.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Spacer()
                                    Text(c.poll?.avg?.percent ?? "–").font(.display(.subheadline, .black)).monospacedDigit()
                                }
                                Bar(poll: c.poll, top: top, color: c.accent(scheme))
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let meta {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Moyenne de \(meta.polls) sondages (\(meta.hypotheses) hypothèses) publiés du \(day(meta.from)) au \(day(meta.to)) : \(meta.pollsters.joined(separator: ", ")). Trait pâle : écart entre hypothèses.")
                    Text("Un sondage mesure un rapport de force à un instant donné, ce n'est pas une prédiction.")
                    Link("Tous les sondages sur Wikipédia", destination: meta.source).fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .tint(.primary)
    }

    private func day(_ iso: String) -> String { iso.isoDay?.formatted(.dateTime.day().month(.abbreviated)) ?? iso }

    private struct Bar: View {
        let poll: Poll?
        let top: Double
        let color: Color

        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    if let lo = poll?.min, let hi = poll?.max {
                        Capsule().fill(color.opacity(0.3))
                            .frame(width: max(6, w * (hi - lo) / top))
                            .offset(x: w * lo / top)
                    }
                    Capsule().fill(color.gradient).frame(width: max(6, w * (poll?.avg ?? 0) / top))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
    }
}

/// Rangée horizontale de vignettes, comme les rangées de pochettes d'Onde.
private struct TileRow: View {
    let title: String
    var symbol: String?
    let count: Int
    let candidates: [Candidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: title, symbol: symbol)
                Text("\(count)").font(.display(.subheadline)).opacity(0.5)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(candidates) { c in
                        NavigationLink(value: c) { Tile(candidate: c) }.buttonStyle(.plain).favoriteMenu(c)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollClipDisabled()
        }
    }
}

struct Tile: View {
    let candidate: Candidate
    /// nil : remplit la colonne de la grille.
    var width: CGFloat? = 128
    @Environment(Store.self) private var store

    var body: some View {
        let c = candidate
        VStack(alignment: .leading, spacing: 6) {
            Color.primary.opacity(0.06)
                .aspectRatio(1 / 1.2, contentMode: .fit)
                .frame(width: width)
                .overlay(alignment: .top) { Remote(url: c.photo?.url) }
                .overlay { if c.photo == nil { Text(c.initials).font(.display(.title, .black)).opacity(0.4) } }
                .clipped()
                .overlay(alignment: .bottom) { Rectangle().fill(c.color).frame(height: 4) }
                .overlay(alignment: .topTrailing) {
                    if store.isFavorite(c) {
                        Image(systemName: "star.fill").font(.caption2.weight(.bold)).foregroundStyle(.yellow)
                            .frame(width: 24, height: 24).background(.black.opacity(0.45), in: .circle).padding(7)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if c.partyLogo != nil {
                        PartyMark(candidate: c, size: 15)
                            .frame(width: 28, height: 28)
                            .background(c.deep, in: .circle)
                            .overlay(Circle().strokeBorder(.white.opacity(0.2)))
                            .padding(7).padding(.bottom, 3)
                    }
                }
                .clipShape(.rect(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08)) }
            Text(c.name).font(.footnote.weight(.semibold)).lineLimit(2)
            Text(c.primary ?? c.party ?? "Sans étiquette").font(.caption).opacity(0.6).lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).foregroundStyle(.secondary) }
            Text(title).font(.display(.title3))
        }
        .accessibilityAddTraits(.isHeader)
    }
}

private struct Footer: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let error = store.error { Label(error, systemImage: "wifi.slash") }
            Text("Mis à jour le \(store.data.updatedAt.formatted(date: .long, time: .shortened)).")
            Text("« Déclaré » n'est pas « officiel » : la liste définitive sera publiée par le Conseil constitutionnel après les 500 parrainages (mars 2027).")
            Text("Sources : Wikipédia (CC BY-SA), Wikidata, Google Actualités, YouTube, Apple Podcasts, Bluesky.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension View {
    /// Appui long : suivre / ne plus suivre.
    func favoriteMenu(_ c: Candidate) -> some View { modifier(FavoriteMenu(candidate: c)) }
}

private struct FavoriteMenu: ViewModifier {
    let candidate: Candidate
    @Environment(Store.self) private var store

    func body(content: Content) -> some View {
        content.contextMenu {
            Button { withAnimation(.snappy) { store.toggleFavorite(candidate) } } label: {
                store.isFavorite(candidate) ? Label("Ne plus suivre", systemImage: "star.slash") : Label("Suivre", systemImage: "star")
            }
        }
    }
}
