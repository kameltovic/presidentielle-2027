import Charts
import SwiftUI

struct CandidateView: View {
    let candidate: Candidate
    private var c: Candidate { candidate }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Hero(candidate: c)
                VStack(spacing: 16) {
                    stats
                    if !c.socials.isEmpty { socials }
                    if let poll = c.poll, poll.history.count > 1 { PollCard(candidate: c, poll: poll) }
                    if c.slogan != nil || c.campaignLogo != nil { campaign }
                    if let roles = c.roles, !roles.isEmpty { functions(roles) }
                    if !c.videos.isEmpty { videos }
                    if !c.news.isEmpty {
                        Card(title: "Actus", systemImage: "newspaper.fill") {
                            ForEach(c.news.prefix(10), id: \.url) { NewsRow(title: $0.title, meta: [$0.source, $0.date.short], url: $0.url) }
                        }
                    }
                    if let posts = c.posts, !posts.isEmpty {
                        Card(title: "Sur Bluesky", systemImage: "cloud.fill") {
                            ForEach(posts, id: \.url) { p in
                                NewsRow(title: p.text.isEmpty ? "(média)" : p.text, meta: [p.date.short, p.likes.map { "♥ \($0)" }, p.reposts.map { "↻ \($0)" }], url: p.url, weight: .regular)
                            }
                        }
                    }
                    if !c.podcasts.isEmpty {
                        Card(title: "Podcasts", systemImage: "headphones") {
                            ForEach(c.podcasts, id: \.url) { p in
                                NewsRow(title: p.title, meta: [p.show, p.date.short, p.duration.map { "\($0) min" }], url: p.url)
                            }
                        }
                    }
                    credits
                }
                .padding(.horizontal)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Backdrop(color: c.color))
        .tint(c.accent(scheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

    // Chiffres clés : même trois cases pour tout le monde.
    private var stats: some View {
        HStack(spacing: 0) {
            Stat(value: c.poll?.avg?.percent ?? "–", label: "Sondages")
            Divider().frame(height: 36)
            Stat(value: c.rank?.ordinal ?? "–", label: "Rang")
            Divider().frame(height: 36)
            Stat(value: c.age.map { "\($0) ans" } ?? "–", label: "Âge")
        }
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 24, style: .continuous))
    }

    private struct Stat: View {
        let value: String, label: String
        var body: some View {
            VStack(spacing: 2) {
                Text(value).font(.display(.title2, .black)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.display(.caption, .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var socials: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer {
                HStack(spacing: 8) {
                    ForEach(c.socials, id: \.url) { s in
                        Link(destination: s.url) { Label(s.label, systemImage: s.icon).font(.display(.subheadline, .medium)) }
                            .buttonStyle(.glass)
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var campaign: some View {
        Card(title: "Campagne", systemImage: "megaphone.fill") {
            HStack(spacing: 16) {
                if let logo = c.campaignLogo {
                    Remote(url: logo.url, fit: true).frame(width: 96, height: 72)
                }
                if let slogan = c.slogan {
                    Text("« \(slogan) »").font(.display(.title3, .heavy)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func functions(_ roles: [String]) -> some View {
        Card(title: "Fonctions", systemImage: "building.columns.fill") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(roles, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(Bullet()) }
            }
            .font(.subheadline)
            if let wiki = c.wikipedia {
                Link(destination: wiki) { Label("Biographie et positions sur Wikipédia", systemImage: "arrow.up.right") }
                    .font(.display(.footnote))
            }
        }
    }

    private var videos: some View {
        Card(title: "Vidéos", systemImage: "play.rectangle.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(c.videos, id: \.id) { v in
                        Link(destination: v.url) {
                            VStack(alignment: .leading, spacing: 6) {
                                Remote(url: v.thumbnail)
                                    .frame(width: 220, height: 124)
                                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                                    .overlay { Image(systemName: "play.fill").font(.title2).foregroundStyle(.white).shadow(radius: 4) }
                                Text(v.title).font(.display(.subheadline, .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                                Text([v.channel, v.date.short].compactMap(\.self).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(width: 220, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
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
        .foregroundStyle(.secondary)
        .tint(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}

/// Photo pleine largeur qui s'étire quand on tire vers le bas, nom et parti par-dessus.
private struct Hero: View {
    let candidate: Candidate

    var body: some View {
        let c = candidate
        Color.clear
            .frame(height: 440)
            .overlay(alignment: .top) { Remote(url: c.photo?.url) }
            .overlay { if c.photo == nil { Text(c.initials).font(.system(size: 90, weight: .black).width(.expanded)).foregroundStyle(.secondary) } }
            .overlay {
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.25),
                    .init(color: c.deep.opacity(0.55), location: 0.62),
                    .init(color: c.deep, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(c.primary ?? c.status.badge)
                        .font(.display(.caption, .bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                    Text(c.name).font(.display(.largeTitle, .black)).lineLimit(2).minimumScaleFactor(0.6)
                    PartyBadge(candidate: c, font: .subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34, style: .continuous))
            .visualEffect { content, geo in
                // Étirement vers le haut quand on tire la page.
                let y = geo.frame(in: .scrollView).minY
                return content.scaleEffect(y > 0 ? 1 + y / 440 : 1, anchor: .bottom)
            }
    }
}

/// Historique des sondages : un point par sondage, moyenne des hypothèses.
private struct PollCard: View {
    let candidate: Candidate
    let poll: Poll
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Six derniers mois : au-delà, l'axe devient illisible et les hypothèses de 2025 ne sont plus comparables.
        let recent = poll.history.filter { $0.day > .now.addingTimeInterval(-183 * 86_400) }
        Card(title: "Sondages", systemImage: "chart.xyaxis.line") {
            Chart {
                ForEach(recent, id: \.self) { p in
                    LineMark(x: .value("Date", p.day), y: .value("%", p.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(candidate.accent(scheme).gradient)
                    PointMark(x: .value("Date", p.day), y: .value("%", p.value))
                        .symbolSize(28)
                        .foregroundStyle(candidate.accent(scheme))
                }
                if let avg = poll.avg {
                    RuleMark(y: .value("Moyenne", avg))
                        .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("moyenne \(avg.percent)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d)) %") } } } }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
            .frame(height: 180)

            if let lo = poll.min, let hi = poll.max {
                Text("Entre \(lo.percent) et \(hi.percent) selon les hypothèses des 30 derniers jours (\(poll.n) testées). Dernier : \(poll.history.last!.pollster), \(poll.history.last!.day.short).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Ligne titre + métadonnées qui ouvre le lien (Safari, YouTube, Podcasts…).
struct NewsRow: View {
    let title: String
    let meta: [String?]
    let url: URL
    var weight: Font.Weight = .semibold

    var body: some View {
        Link(destination: url) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.subheadline, weight: weight)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                Text(meta.compactMap(\.self).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct Bullet: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.tint)
            configuration.title
        }
    }
}
