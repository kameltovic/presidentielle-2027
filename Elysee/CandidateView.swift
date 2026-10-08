import Charts
import SwiftUI

/// Fiche candidat, façon page d'émission d'Onde : la page prend la couleur sombre du parti,
/// grande photo en tête, bouton Suivre, puis des rangées d'images (actus, vidéos, podcasts).
struct CandidateView: View {
    let candidate: Candidate
    private var c: Candidate { candidate }
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(candidate: c)
                VStack(alignment: .leading, spacing: 30) {
                    header
                    stats
                    if let poll = c.poll, poll.history.count > 1 { PollSection(candidate: c, poll: poll) }
                    if c.slogan != nil || c.campaignLogo != nil { campaign }
                    if !newsWithImages.isEmpty { headlines }
                    if !c.videos.isEmpty { videos }
                    if !c.podcasts.isEmpty { podcasts }
                    if let posts = c.posts, !posts.isEmpty { bluesky(posts) }
                    if !otherNews.isEmpty { moreNews }
                    if let roles = c.roles, !roles.isEmpty { functions(roles) }
                    credits
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background { background.ignoresSafeArea() }
        .foregroundStyle(.white)
        .tint(.white)
        .environment(\.colorScheme, .dark) // page immersive : toujours sombre, comme Onde
        // Les barres (et l'estompage du bas sous la barre d'onglets) suivent sinon le thème clair → bande blanche.
        .toolbarColorScheme(.dark, for: .navigationBar, .tabBar)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            c.deep
            Aura(colors: Aura.palette(c.color).map { $0.mix(with: c.deep, by: 0.4) }, dim: 0.25)
                .frame(height: 900)
                .mask(LinearGradient(colors: [.clear, .black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: En-tête

    private var header: some View {
        let following = store.isFavorite(c)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text((c.primary ?? c.status.badge).uppercased()).font(.caption.weight(.bold)).tracking(1.2).opacity(0.75)
                if let rank = c.rank {
                    Text("· \(rank.ordinal) dans les sondages".uppercased()).font(.caption.weight(.bold)).tracking(1.2).opacity(0.75)
                }
            }
            Text(c.name).font(.display(.largeTitle, .black)).fixedSize(horizontal: false, vertical: true)
            PartyBadge(candidate: c, font: .subheadline.weight(.bold))
            HStack(spacing: 10) {
                Button { withAnimation(.snappy) { store.toggleFavorite(c) } } label: {
                    Label(following ? "Suivi" : "Suivre", systemImage: following ? "star.fill" : "star")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .foregroundStyle(following ? Color.white : c.deep)
                        .background(following ? AnyShapeStyle(Color.white.opacity(0.15)) : AnyShapeStyle(Color.white), in: .capsule)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: following)
                .accessibilityHint(following ? "Retirer des favoris" : "Ajouter aux favoris")

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(c.socials, id: \.url) { s in
                            Link(destination: s.url) {
                                Image(systemName: s.icon).font(.subheadline.weight(.semibold)).frame(width: 42, height: 42)
                            }
                            .background(.white.opacity(0.12), in: .circle)
                            .accessibilityLabel(s.label)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            .padding(.top, 4)
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            Stat(value: c.poll?.avg?.percent ?? "–", label: "Sondages")
            Stat(value: c.rank?.ordinal ?? "–", label: "Rang")
            Stat(value: c.age.map { "\($0) ans" } ?? "–", label: "Âge")
        }
        .padding(.vertical, 16)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22, style: .continuous))
    }

    private struct Stat: View {
        let value: String, label: String
        var body: some View {
            VStack(spacing: 2) {
                Text(value).font(.display(.title2, .black)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(1).opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Campagne

    private var campaign: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Campagne")
            HStack(spacing: 16) {
                if let logo = c.campaignLogo {
                    Remote(url: logo.url, fit: true)
                        .frame(width: 92, height: 92)
                        .padding(10)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 20, style: .continuous))
                }
                if let slogan = c.slogan {
                    Text("« \(slogan) »").font(.display(.title3, .heavy)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Médias

    private var newsItems: [FeedView.Item] {
        c.news.map { FeedView.Item(id: $0.url, candidate: c, title: $0.title, source: $0.source, excerpt: $0.excerpt, date: $0.date, image: $0.image, kind: .actus) }
    }
    private var newsWithImages: [FeedView.Item] { Array(newsItems.filter { $0.image != nil }.prefix(8)) }
    private var otherNews: [FeedView.Item] { newsItems.filter { item in !newsWithImages.contains { $0.id == item.id } } }

    /// Actus illustrées en grandes cartes qui défilent.
    private var headlines: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "À la une", symbol: "newspaper.fill")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(newsWithImages) { item in
                        Link(destination: item.id) { Headline(item: item) }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal) { w, _ in w - 56 }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private var videos: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Vidéos", symbol: "play.rectangle.fill")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(c.videos, id: \.id) { v in
                        Link(destination: v.url) {
                            VStack(alignment: .leading, spacing: 8) {
                                Remote(url: v.thumbnail)
                                    .frame(width: 260, height: 146)
                                    .clipShape(.rect(cornerRadius: 20, style: .continuous))
                                    .overlay {
                                        Image(systemName: "play.fill").font(.title3).frame(width: 48, height: 48).glassEffect(.regular, in: .circle)
                                    }
                                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                                Text(v.title).font(.footnote.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                                Text([v.channel, v.date.short].compactMap(\.self).joined(separator: " · ")).font(.caption).opacity(0.6)
                            }
                            .frame(width: 260, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    /// Pochettes en rangée, comme les rangées d'émissions d'Onde.
    private var podcasts: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Podcasts", symbol: "headphones")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(c.podcasts, id: \.url) { p in
                        Link(destination: p.url) {
                            VStack(alignment: .leading, spacing: 8) {
                                Remote(url: p.artwork ?? c.photo?.url)
                                    .frame(width: 150, height: 150)
                                    .clipShape(.rect(cornerRadius: 20, style: .continuous))
                                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                                Text(p.title).font(.footnote.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                                Text([p.show, p.duration.map { "\($0) min" }].compactMap(\.self).joined(separator: " · ")).font(.caption).opacity(0.6).lineLimit(1)
                            }
                            .frame(width: 150, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func bluesky(_ posts: [Post]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sur Bluesky", symbol: "cloud.fill")
            ForEach(posts, id: \.url) { p in
                Link(destination: p.url) {
                    VStack(alignment: .leading, spacing: 10) {
                        if !p.text.isEmpty { Text(p.text).font(.subheadline).multilineTextAlignment(.leading) }
                        if let image = p.image {
                            Remote(url: image).frame(height: 180).frame(maxWidth: .infinity)
                                .clipShape(.rect(cornerRadius: 16, style: .continuous))
                        }
                        Text([p.date.short, p.likes.map { "♥ \($0)" }, p.reposts.map { "↻ \($0)" }].compactMap(\.self).joined(separator: "  ·  "))
                            .font(.caption).opacity(0.6)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var moreNews: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: newsWithImages.isEmpty ? "Actus" : "Autres actus", symbol: newsWithImages.isEmpty ? "newspaper.fill" : nil)
            ForEach(otherNews) { Strip(item: $0, showsCandidate: false) }
        }
    }

    private func functions(_ roles: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Fonctions", symbol: "building.columns.fill")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(roles, id: \.self) { r in
                    Text(r).font(.subheadline).padding(.vertical, 11)
                    Divider().overlay(.white.opacity(0.12))
                }
            }
            if let wiki = c.wikipedia {
                Link(destination: wiki) { Label("Biographie et positions sur Wikipédia", systemImage: "arrow.up.right") }
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    /// Les images viennent de Wikimedia Commons : l'attribution est obligatoire.
    private var credits: some View {
        let files = [c.photo, c.campaignLogo, c.partyLogo].compactMap(\.self)
        return VStack(alignment: .leading, spacing: 4) {
            if !files.isEmpty { Text("Images").bold() }
            ForEach(files, id: \.file) { f in
                if let page = f.page {
                    Link(destination: page) {
                        Text([f.file, f.author, f.license].compactMap(\.self).joined(separator: " · ")).multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .font(.caption2)
        .opacity(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Grande photo pleine largeur : parallaxe au défilement, étirement quand on tire.
/// Le bas de la photo devient transparent (masque) au lieu de se fondre dans un aplat :
/// un aplat ne correspond jamais exactement au fond animé et se voyait en glissant sous les boutons.
private struct Hero: View {
    let candidate: Candidate

    var body: some View {
        let c = candidate
        Color.clear
            .aspectRatio(0.82, contentMode: .fit)
            .overlay(alignment: .top) { Remote(url: c.photo?.url) }
            .overlay { if c.photo == nil { Text(c.initials).font(.system(size: 90, weight: .black).width(.expanded)).opacity(0.4) } }
            .clipped()
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom).frame(height: 120)
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .visualEffect { content, proxy in
                let y = proxy.frame(in: .scrollView).minY
                return content
                    .scaleEffect(y > 0 ? 1 + y / max(proxy.size.height, 1) : 1, anchor: .bottom)
                    .offset(y: y > 0 ? 0 : -y * 0.3)
            }
            .accessibilityHidden(true)
    }
}

/// Carte d'actu illustrée (image 16:9 + titre + source).
private struct Headline: View {
    let item: FeedView.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Remote(url: item.image)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            Text([item.source, item.date.short].compactMap(\.self).joined(separator: " · ").uppercased())
                .font(.caption2.weight(.bold)).tracking(1).opacity(0.6).lineLimit(1)
            Text(item.title).font(.headline).lineLimit(3).multilineTextAlignment(.leading)
            if let excerpt = item.excerpt { Text(excerpt).font(.subheadline).opacity(0.7).lineLimit(2).multilineTextAlignment(.leading) }
        }
    }
}

/// Courbe des sondages : un point par sondage (moyenne de ses hypothèses), six derniers mois.
private struct PollSection: View {
    let candidate: Candidate
    let poll: Poll

    var body: some View {
        let recent = poll.history.filter { $0.day > .now.addingTimeInterval(-183 * 86_400) }
        let line = candidate.accent(.dark)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Sondages", symbol: "chart.xyaxis.line")
            Chart {
                ForEach(recent, id: \.self) { p in
                    AreaMark(x: .value("Date", p.day), y: .value("%", p.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [line.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", p.day), y: .value("%", p.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(line)
                        .lineStyle(.init(lineWidth: 2.5))
                    PointMark(x: .value("Date", p.day), y: .value("%", p.value))
                        .symbolSize(24)
                        .foregroundStyle(line)
                }
                if let avg = poll.avg {
                    RuleMark(y: .value("Moyenne", avg))
                        .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.white.opacity(0.5))
                        .annotation(position: .top, alignment: .leading) {
                            Text("moyenne \(avg.percent)").font(.caption2.weight(.semibold)).opacity(0.7)
                        }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) { v in AxisGridLine().foregroundStyle(.white.opacity(0.1)); AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d)) %") } } } }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
            .frame(height: 190)

            if let lo = poll.min, let hi = poll.max, let last = poll.history.last {
                Text("Entre \(lo.percent) et \(hi.percent) selon les hypothèses des 30 derniers jours (\(poll.n) testées). Dernier : \(last.pollster), \(last.day.short).")
                    .font(.caption).opacity(0.6)
            }
        }
    }
}
