import Foundation

/// Miroir de data/candidats.json (produit par scripts/sync.mjs).
struct Dataset: Codable, Sendable {
    let updatedAt: Date
    let polls: PollMeta?
    let candidats: [Candidate]
}

/// Fenêtre des sondages utilisés pour la moyenne (30 jours avant le dernier publié).
struct PollMeta: Codable, Sendable {
    let from: String
    let to: String
    let polls: Int
    let hypotheses: Int
    let pollsters: [String]
    let source: URL
}

struct PollPoint: Codable, Hashable, Sendable {
    let date: String
    let pollster: String
    let value: Double
    var day: Date { (try? Date(date, strategy: .iso8601.year().month().day())) ?? .distantPast }
}

struct Poll: Codable, Hashable, Sendable {
    let avg: Double?
    let min: Double?
    let max: Double?
    let n: Int
    let rank: Int?
    let history: [PollPoint]
}

extension String {
    /// "2026-09-29" → date.
    var isoDay: Date? { try? Date(self, strategy: .iso8601.year().month().day()) }
}

enum Status: String, Codable, CaseIterable, Sendable {
    case declare, primaire, pressenti

    var title: String {
        switch self {
        case .declare: "Candidats déclarés"
        case .primaire: "En primaire"
        case .pressenti: "Pressentis"
        }
    }

    var badge: String {
        switch self {
        case .declare: "Déclaré"
        case .primaire: "Primaire"
        case .pressenti: "Pressenti"
        }
    }
}

struct Media: Codable, Hashable, Sendable {
    let file: String
    let url: URL
    let page: URL?
    let author: String?
    let license: String?
}

struct Links: Codable, Hashable, Sendable {
    let site: String?
    let x: String?
    let youtube: String?
    let bluesky: String?
    let instagram: String?
    let tiktok: String?
}

struct News: Codable, Hashable, Sendable {
    let title: String
    let url: URL
    let source: String?
    let excerpt: String?
    let image: URL?
    let date: Date
}

struct Video: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let channel: String?
    let date: Date
    var url: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
    var thumbnail: URL { URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")! }
}

struct Podcast: Codable, Hashable, Sendable {
    let title: String
    let show: String?
    let url: URL
    let artwork: URL?
    let date: Date
    let duration: Int?
}

struct Post: Codable, Hashable, Sendable {
    let text: String
    let image: URL?
    let date: Date
    let likes: Int?
    let reposts: Int?
    let url: URL
}

struct Candidate: Codable, Identifiable, Hashable, Sendable {
    let slug: String
    let name: String
    let wiki: String?
    let sortName: String
    let roles: [String]?
    let party: String?
    let photo: Media?
    let campaignLogo: Media?
    let partyLogo: Media?
    let partyColor: String?
    let poll: Poll?
    let slogan: String?
    let birth: String?
    let status: Status
    let primary: String?
    let links: Links
    let news: [News]
    let videos: [Video]
    let podcasts: [Podcast]
    let posts: [Post]?

    var id: String { slug }
    static func == (a: Self, b: Self) -> Bool { a.slug == b.slug }
    func hash(into h: inout Hasher) { h.combine(slug) }

    var rank: Int? { poll?.rank }

    var initials: String { name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined() }

    var age: Int? {
        guard let birth, let d = try? Date(birth, strategy: .iso8601.year().month().day()) else { return nil }
        return Calendar.current.dateComponents([.year], from: d, to: .now).year
    }

    var wikipedia: URL? {
        wiki.flatMap { URL(string: "https://fr.wikipedia.org/wiki/" + $0.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!) }
    }

    /// Réseaux à afficher, dans un ordre fixe pour tout le monde.
    var socials: [(label: String, icon: String, url: URL)] {
        [
            ("Site", "globe", links.site.flatMap(URL.init(string:))),
            ("X", "xmark", links.x.flatMap { URL(string: "https://x.com/\($0)") }),
            ("Bluesky", "cloud", links.bluesky.flatMap { URL(string: "https://bsky.app/profile/\($0)") }),
            ("YouTube", "play.rectangle", links.youtube.flatMap { URL(string: "https://www.youtube.com/channel/\($0)") }),
            ("Instagram", "camera", links.instagram.flatMap { URL(string: "https://www.instagram.com/\($0)") }),
            ("TikTok", "music.note", links.tiktok.flatMap { URL(string: "https://www.tiktok.com/@\($0)") }),
        ].compactMap { l in l.2.map { (l.0, l.1, $0) } }
    }
}

extension JSONDecoder {
    static let dataset: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = try? Date(s, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) { return date }
            if let date = try? Date(s, strategy: .iso8601) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Date invalide : \(s)"))
        }
        return d
    }()
}
